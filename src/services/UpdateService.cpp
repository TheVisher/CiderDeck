#include "UpdateService.h"

#include <QDateTime>
#include <QProcess>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTimer>

#include <cerrno>
#include <csignal>
#include <fcntl.h>
#include <pty.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>

namespace ciderdeck {

UpdateService::UpdateService(QObject *parent)
    : QObject(parent)
    , officialProcess_(new QProcess(this))
    , aurProcess_(new QProcess(this))
    , flatpakProcess_(new QProcess(this))
    , updateProcess_(new QProcess(this))
    , refreshTimer_(new QTimer(this))
    , timeoutTimer_(new QTimer(this))
    , terminalPollTimer_(new QTimer(this)) {
    refreshTimer_->setInterval(30 * 60 * 1000);
    timeoutTimer_->setSingleShot(true);
    terminalPollTimer_->setInterval(100);

    connect(refreshTimer_, &QTimer::timeout, this, &UpdateService::refresh);
    connect(timeoutTimer_, &QTimer::timeout, this, [this]() {
        for (int i = 0; i < 3; ++i) {
            const auto source = static_cast<Source>(i);
            if (!pending_[i])
                continue;
            QProcess *process = processFor(source);
            if (process->state() != QProcess::NotRunning)
                process->kill();
            failCheck(source, QStringLiteral("timed out"));
        }
    });

    const auto connectProcess = [this](QProcess *process, Source source) {
        connect(process, &QProcess::finished, this,
                [this, source](int exitCode, QProcess::ExitStatus status) {
                    finishCheck(source, exitCode, status == QProcess::CrashExit);
                });
        connect(process, &QProcess::errorOccurred, this,
                [this, source](QProcess::ProcessError error) {
                    if (error == QProcess::FailedToStart)
                        failCheck(source, QStringLiteral("command unavailable"));
                });
    };

    connectProcess(officialProcess_, Source::Official);
    connectProcess(aurProcess_, Source::Aur);
    connectProcess(flatpakProcess_, Source::Flatpak);

    connect(terminalPollTimer_, &QTimer::timeout,
            this, &UpdateService::pollTerminalProcess);

    // Konsole remains a fallback when a PTY cannot be created.
    connect(updateProcess_, &QProcess::started, this, &UpdateService::updated);
    connect(updateProcess_, &QProcess::finished, this, [this]() {
        emit updated();
        QTimer::singleShot(1500, this, &UpdateService::refresh);
    });
    connect(updateProcess_, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            errors_.append(QStringLiteral("Konsole could not be opened"));
            emit updated();
        }
    });

    QTimer::singleShot(1200, this, &UpdateService::refresh);
    refreshTimer_->start();
}

UpdateService::~UpdateService() {
    if (terminalPid_ > 0) {
        ::kill(-static_cast<pid_t>(terminalPid_), SIGKILL);
        ::kill(static_cast<pid_t>(terminalPid_), SIGKILL);
        int status = 0;
        ::waitpid(static_cast<pid_t>(terminalPid_), &status, 0);
    }
    closeTerminalDescriptor();
}

bool UpdateService::updateRunning() const {
    return terminalActive_ || updateProcess_->state() != QProcess::NotRunning;
}

QStringList UpdateService::allUpdates() const {
    QStringList updates;
    updates.reserve(totalCount());
    updates.append(officialUpdates_);
    updates.append(aurUpdates_);
    updates.append(flatpakUpdates_);
    return updates;
}

void UpdateService::refresh() {
    if (checking_)
        return;

    checking_ = true;
    errors_.clear();
    pending_.fill(false);
    emit updated();

    startCheck(Source::Official, QStringLiteral("checkupdates"), {QStringLiteral("--nocolor")});
    startCheck(Source::Aur, QStringLiteral("paru"),
               {QStringLiteral("-Qua"), QStringLiteral("--color"), QStringLiteral("never")});
    startCheck(Source::Flatpak, QStringLiteral("flatpak"),
               {QStringLiteral("remote-ls"), QStringLiteral("--updates"),
                QStringLiteral("--columns=application,name,version")});
    timeoutTimer_->start(60 * 1000);
}

void UpdateService::updateAll() {
    if (updateRunning())
        return;

    errors_.clear();
    const QString command = updateCommandScript();
    if (!startEmbeddedUpdate(command))
        startExternalUpdate(command);
}

QString UpdateService::updateCommandScript() {
    return QStringLiteral(R"SCRIPT(
clear
printf '\n\033[1;36mCiderDeck System Update\033[0m\n\n'
arch_status=0
flatpak_status=0
pacman_lock=/var/lib/pacman/db.lck

active_package_manager() {
    for manager in pacman paru yay pikaur trizen pamac; do
        if pgrep -x "$manager" >/dev/null 2>&1; then
            printf '%s' "$manager"
            return 0
        fi
    done
    return 1
}

while [ -e "$pacman_lock" ]; do
    manager=$(active_package_manager)
    if [ -n "$manager" ]; then
        printf '\033[1;33mPacman is actively in use by %s.\033[0m\n' "$manager"
        printf 'CiderDeck will wait and retry. Press Ctrl+C to cancel.\n'
        while [ -e "$pacman_lock" ] && active_package_manager >/dev/null; do
            sleep 3
        done
        printf '\nChecking the Pacman lock again...\n'
        continue
    fi

    lock_time=$(stat -c '%y' "$pacman_lock" 2>/dev/null | cut -d. -f1)
    printf '\033[1;33mStale Pacman lock detected.\033[0m\n'
    printf 'No package manager is running, but this file was left behind:\n  %s\n' "$pacman_lock"
    if [ -n "$lock_time" ]; then
        printf 'It was last changed: %s\n' "$lock_time"
    fi
    printf 'This usually means an earlier update was canceled or interrupted.\n\n'
    printf 'Remove the stale lock and continue? [y/N]: '
    IFS= read -r clear_lock

    case "$clear_lock" in
        y|Y|yes|YES|Yes)
            manager=$(active_package_manager)
            if [ -n "$manager" ]; then
                printf '\n\033[1;31m%s started before the lock could be cleared. Nothing was removed.\033[0m\n' "$manager"
                continue
            fi
            if sudo rm -f -- "$pacman_lock" && [ ! -e "$pacman_lock" ]; then
                printf '\033[1;32mStale lock cleared. Continuing with updates.\033[0m\n\n'
            else
                printf '\033[1;31mThe stale lock could not be removed.\033[0m\n'
                arch_status=75
                break
            fi
            ;;
        *)
            printf '\nLock left untouched; skipping Arch updates.\n'
            arch_status=75
            break
            ;;
    esac
done

printf '\033[1mArch repositories and AUR\033[0m\n'
if [ "$arch_status" -ne 0 ]; then
    printf 'Arch updates were skipped.\n'
elif command -v paru >/dev/null 2>&1; then
    paru -Syu || arch_status=$?
else
    printf '\033[1;31mparu is not installed.\033[0m\n'
    arch_status=127
fi

printf '\n\033[1mFlatpak\033[0m\n'
if command -v flatpak >/dev/null 2>&1; then
    flatpak update || flatpak_status=$?
else
    printf 'Flatpak is not installed; skipping.\n'
fi

printf '\n'
if [ "$arch_status" -eq 0 ] && [ "$flatpak_status" -eq 0 ]; then
    printf '\033[1;32mAll updates completed.\033[0m\n'
    overall_status=0
else
    printf '\033[1;31mOne or more update steps did not complete.\033[0m\n'
    overall_status=1
fi
printf '\nPress Enter to return to CiderDeck...'
IFS= read -r _
exit "$overall_status"
)SCRIPT");
}

bool UpdateService::startEmbeddedUpdate(const QString &command) {
    struct winsize size {};
    size.ws_col = static_cast<unsigned short>(terminalColumns_);
    size.ws_row = static_cast<unsigned short>(terminalRows_);

    const QByteArray commandBytes = command.toUtf8();
    int masterFd = -1;
    const pid_t pid = ::forkpty(&masterFd, nullptr, nullptr, &size);
    if (pid < 0)
        return false;

    if (pid == 0) {
        ::execl("/usr/bin/env", "env", "TERM=xterm-256color",
                "/bin/bash", "-c", commandBytes.constData(),
                static_cast<char *>(nullptr));
        ::_exit(127);
    }

    const int currentFlags = ::fcntl(masterFd, F_GETFL, 0);
    if (currentFlags >= 0)
        ::fcntl(masterFd, F_SETFL, currentFlags | O_NONBLOCK);

    terminalFd_ = masterFd;
    terminalPid_ = pid;
    terminalActive_ = true;
    updateCanceled_ = false;
    terminalRawOutput_.clear();
    terminalOutput_ = QStringLiteral("Starting update session...\n");

    terminalNotifier_ = new QSocketNotifier(terminalFd_, QSocketNotifier::Read, this);
    connect(terminalNotifier_, &QSocketNotifier::activated,
            this, &UpdateService::readTerminalOutput);
    terminalPollTimer_->start();
    emit terminalOutputChanged();
    emit updated();
    return true;
}

void UpdateService::startExternalUpdate(const QString &command) {
    const QString konsole = QStandardPaths::findExecutable(QStringLiteral("konsole"));
    if (konsole.isEmpty()) {
        errors_.append(QStringLiteral("Could not create an embedded terminal, and Konsole is not installed"));
        emit updated();
        return;
    }

    updateProcess_->setProgram(konsole);
    updateProcess_->setArguments({QStringLiteral("--separate"),
                                  QStringLiteral("-p"), QStringLiteral("tabtitle=CiderDeck Updates"),
                                  QStringLiteral("-e"), QStringLiteral("bash"),
                                  QStringLiteral("-lc"), command});
    updateProcess_->start();
}

void UpdateService::sendTerminalInput(const QString &input) {
    if (!terminalActive_ || terminalFd_ < 0 || input.isEmpty())
        return;

    const QByteArray bytes = input.toUtf8();
    qsizetype written = 0;
    while (written < bytes.size()) {
        const ssize_t count = ::write(terminalFd_, bytes.constData() + written,
                                      static_cast<size_t>(bytes.size() - written));
        if (count > 0) {
            written += count;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        break;
    }
}

void UpdateService::cancelUpdate() {
    if (!terminalActive_ || terminalPid_ <= 0)
        return;
    updateCanceled_ = true;
    ::kill(-static_cast<pid_t>(terminalPid_), SIGTERM);
    ::kill(static_cast<pid_t>(terminalPid_), SIGTERM);
    QTimer::singleShot(1500, this, [this]() {
        if (terminalPid_ > 0) {
            ::kill(-static_cast<pid_t>(terminalPid_), SIGKILL);
            ::kill(static_cast<pid_t>(terminalPid_), SIGKILL);
        }
    });
}

void UpdateService::setTerminalSize(int columns, int rows) {
    terminalColumns_ = qBound(40, columns, 240);
    terminalRows_ = qBound(8, rows, 80);
    if (terminalFd_ < 0)
        return;

    struct winsize size {};
    size.ws_col = static_cast<unsigned short>(terminalColumns_);
    size.ws_row = static_cast<unsigned short>(terminalRows_);
    ::ioctl(terminalFd_, TIOCSWINSZ, &size);
}

void UpdateService::readTerminalOutput() {
    if (terminalFd_ < 0)
        return;

    char buffer[8192];
    bool received = false;
    while (true) {
        const ssize_t count = ::read(terminalFd_, buffer, sizeof(buffer));
        if (count > 0) {
            terminalRawOutput_.append(buffer, static_cast<qsizetype>(count));
            received = true;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        break;
    }

    if (!received)
        return;

    constexpr qsizetype maximumRawOutput = 512 * 1024;
    constexpr qsizetype retainedRawOutput = 384 * 1024;
    if (terminalRawOutput_.size() > maximumRawOutput) {
        qsizetype firstLine = terminalRawOutput_.indexOf(
            '\n', terminalRawOutput_.size() - retainedRawOutput);
        if (firstLine < 0)
            firstLine = terminalRawOutput_.size() - retainedRawOutput;
        terminalRawOutput_.remove(0, firstLine + 1);
    }

    terminalOutput_ = sanitizeTerminalOutput(terminalRawOutput_);
    emit terminalOutputChanged();
}

void UpdateService::pollTerminalProcess() {
    if (terminalPid_ <= 0)
        return;

    int status = 0;
    const pid_t result = ::waitpid(static_cast<pid_t>(terminalPid_), &status, WNOHANG);
    if (result == 0)
        return;
    if (result < 0 && errno == EINTR)
        return;

    readTerminalOutput();
    finishTerminalProcess(result < 0 ? -1 : status);
}

void UpdateService::finishTerminalProcess(int status) {
    terminalPollTimer_->stop();
    const bool canceled = updateCanceled_;
    const bool succeeded = status >= 0 && WIFEXITED(status) && WEXITSTATUS(status) == 0;

    terminalPid_ = -1;
    terminalActive_ = false;
    updateCanceled_ = false;
    closeTerminalDescriptor();

    if (canceled)
        errors_.append(QStringLiteral("Update canceled"));
    else if (!succeeded)
        errors_.append(QStringLiteral("One or more update steps did not complete"));

    emit updated();
    QTimer::singleShot(600, this, &UpdateService::refresh);
}

void UpdateService::closeTerminalDescriptor() {
    if (terminalNotifier_) {
        terminalNotifier_->setEnabled(false);
        terminalNotifier_->deleteLater();
        terminalNotifier_ = nullptr;
    }
    if (terminalFd_ >= 0) {
        ::close(terminalFd_);
        terminalFd_ = -1;
    }
}

QString UpdateService::sanitizeTerminalOutput(const QByteArray &output) {
    QString text = QString::fromUtf8(output);

    static const QRegularExpression oscSequence(
        QStringLiteral("\\x1b\\][^\\x07]*(?:\\x07|\\x1b\\\\)"));
    static const QRegularExpression csiSequence(
        QStringLiteral("\\x1b\\[[0-?]*[ -/]*[@-~]"));
    static const QRegularExpression shortEscape(
        QStringLiteral("\\x1b[()][0-2A-Z]|\\x1b[@-_]"));
    text.remove(oscSequence);
    text.remove(csiSequence);
    text.remove(shortEscape);

    QString rendered;
    rendered.reserve(text.size());
    qsizetype lineStart = 0;
    for (qsizetype index = 0; index < text.size(); ++index) {
        const QChar character = text.at(index);
        if (character == u'\r') {
            // PTYs normally translate a newline to CRLF. The CR in that pair
            // is not an in-place progress update and must not erase the line
            // that was just rendered.
            if (index + 1 < text.size() && text.at(index + 1) == u'\n')
                continue;
            rendered.truncate(lineStart);
            continue;
        }
        if (character == u'\n') {
            rendered.append(character);
            lineStart = rendered.size();
            continue;
        }
        if (character == u'\b') {
            if (rendered.size() > lineStart)
                rendered.chop(1);
            continue;
        }
        if (character.unicode() >= 0x20 || character == u'\t')
            rendered.append(character);
    }
    return rendered;
}

void UpdateService::startCheck(Source source, const QString &program, const QStringList &arguments) {
    const int index = static_cast<int>(source);
    pending_[index] = true;

    QProcess *process = processFor(source);
    process->setProgram(program);
    process->setArguments(arguments);
    process->start();
}

void UpdateService::finishCheck(Source source, int exitCode, bool crashed) {
    const int index = static_cast<int>(source);
    if (!pending_[index])
        return;

    QProcess *process = processFor(source);
    const QStringList lines = outputLines(process->readAllStandardOutput());
    const QString stderrText = QString::fromUtf8(process->readAllStandardError()).trimmed();

    const bool noOfficialUpdates = source == Source::Official && exitCode == 2 && !crashed;
    const bool noAurUpdates = source == Source::Aur && exitCode == 1 && !crashed
                              && lines.isEmpty() && stderrText.isEmpty();
    if ((!crashed && exitCode == 0) || noOfficialUpdates || noAurUpdates) {
        if (source == Source::Official)
            officialUpdates_ = noOfficialUpdates ? QStringList{} : lines;
        else if (source == Source::Aur)
            aurUpdates_ = noAurUpdates ? QStringList{} : lines;
        else
            flatpakUpdates_ = lines;
        completeSource(source);
        return;
    }

    QString message = stderrText.section('\n', 0, 0).trimmed();
    if (message.isEmpty())
        message = QStringLiteral("check failed");
    failCheck(source, message);
}

void UpdateService::failCheck(Source source, const QString &message) {
    const int index = static_cast<int>(source);
    if (!pending_[index])
        return;
    errors_.append(sourceName(source) + QStringLiteral(": ") + message);
    completeSource(source);
}

void UpdateService::completeSource(Source source) {
    pending_[static_cast<int>(source)] = false;
    const bool anyPending = pending_[0] || pending_[1] || pending_[2];
    if (anyPending)
        return;

    timeoutTimer_->stop();
    checking_ = false;
    hasChecked_ = true;
    lastChecked_ = QDateTime::currentDateTime().toString(QStringLiteral("h:mm AP"));
    emit updated();
}

QProcess *UpdateService::processFor(Source source) const {
    if (source == Source::Official)
        return officialProcess_;
    if (source == Source::Aur)
        return aurProcess_;
    return flatpakProcess_;
}

QString UpdateService::sourceName(Source source) {
    if (source == Source::Official)
        return QStringLiteral("Official");
    if (source == Source::Aur)
        return QStringLiteral("AUR");
    return QStringLiteral("Flatpak");
}

QStringList UpdateService::outputLines(const QByteArray &output) {
    QStringList lines;
    for (const QString &line : QString::fromUtf8(output).split('\n', Qt::SkipEmptyParts)) {
        const QString trimmed = line.trimmed();
        if (!trimmed.isEmpty())
            lines.append(trimmed);
    }
    return lines;
}

} // namespace ciderdeck
