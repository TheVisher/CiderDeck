#include "UpdateService.h"

#include <QDateTime>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>

namespace ciderdeck {

UpdateService::UpdateService(QObject *parent)
    : QObject(parent)
    , officialProcess_(new QProcess(this))
    , aurProcess_(new QProcess(this))
    , flatpakProcess_(new QProcess(this))
    , updateProcess_(new QProcess(this))
    , refreshTimer_(new QTimer(this))
    , timeoutTimer_(new QTimer(this)) {
    refreshTimer_->setInterval(30 * 60 * 1000);
    timeoutTimer_->setSingleShot(true);

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

bool UpdateService::updateRunning() const {
    return updateProcess_->state() != QProcess::NotRunning;
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

    const QString konsole = QStandardPaths::findExecutable(QStringLiteral("konsole"));
    if (konsole.isEmpty()) {
        errors_.append(QStringLiteral("Konsole is not installed"));
        emit updated();
        return;
    }

    const QString script = QStringLiteral(R"SCRIPT(
clear
printf '\n\033[1;36mCiderDeck System Update\033[0m\n\n'
arch_status=0
flatpak_status=0

printf '\033[1mArch repositories and AUR\033[0m\n'
paru -Syu || arch_status=$?

printf '\n\033[1mFlatpak\033[0m\n'
flatpak update || flatpak_status=$?

printf '\n'
if [ "$arch_status" -eq 0 ] && [ "$flatpak_status" -eq 0 ]; then
    printf '\033[1;32mAll updates completed.\033[0m\n'
else
    printf '\033[1;31mOne or more update steps did not complete.\033[0m\n'
fi
printf '\nPress Enter to close...'
read -r
)SCRIPT");

    updateProcess_->setProgram(konsole);
    updateProcess_->setArguments({QStringLiteral("--separate"),
                                  QStringLiteral("-p"), QStringLiteral("tabtitle=CiderDeck Updates"),
                                  QStringLiteral("-e"), QStringLiteral("bash"),
                                  QStringLiteral("-lc"), script});
    updateProcess_->start();
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
