#include "AgentTerminalService.h"

#include <QClipboard>
#include <QDir>
#include <QGuiApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUuid>

namespace ciderdeck {

namespace {

QString normalizedProvider(const QString &provider) {
    const QString normalized = provider.trimmed().toLower();
    if (normalized == QStringLiteral("codex") ||
        normalized == QStringLiteral("claude") ||
        normalized == QStringLiteral("shell")) {
        return normalized;
    }
    return {};
}

QString displayProvider(const QString &provider) {
    if (provider == QStringLiteral("codex"))
        return QStringLiteral("Codex");
    if (provider == QStringLiteral("claude"))
        return QStringLiteral("Claude");
    return QStringLiteral("Shell");
}

struct CapturedPane {
    QString output;
    QString modelName;
};

CapturedPane cleanCapturedPane(QString output, const QString &provider) {
    QStringList lines = output.split(u'\n');
    while (!lines.isEmpty() && lines.constLast().trimmed().isEmpty())
        lines.removeLast();

    QString modelName;
    if (provider == QStringLiteral("codex")) {
        static const QRegularExpression statusPattern(
            QStringLiteral("^\\s*(gpt-[^·\\r\\n]+?)\\s*·\\s*.+$"));
        static const QRegularExpression modelBoxPattern(
            QStringLiteral("model:\\s*(.+?)\\s+/model\\s+to\\s+change"),
            QRegularExpression::CaseInsensitiveOption);

        for (int i = lines.size() - 1; i >= 0; --i) {
            const auto statusMatch = statusPattern.match(lines.at(i));
            if (statusMatch.hasMatch()) {
                modelName = statusMatch.captured(1).trimmed();
                break;
            }
        }

        if (modelName.isEmpty()) {
            for (const QString &line : lines) {
                const auto modelMatch = modelBoxPattern.match(line);
                if (modelMatch.hasMatch()) {
                    const QString candidate = modelMatch.captured(1).trimmed();
                    if (candidate.compare(QStringLiteral("loading"), Qt::CaseInsensitive) != 0)
                        modelName = candidate;
                }
            }
        }

        QStringList cleanedLines;
        bool skippingBanner = false;
        for (int i = 0; i < lines.size(); ++i) {
            const QString trimmed = lines.at(i).trimmed();

            if (!skippingBanner && trimmed.startsWith(QStringLiteral("╭"))) {
                bool codexBanner = false;
                for (int lookAhead = i + 1;
                     lookAhead < qMin(lines.size(), i + 7); ++lookAhead) {
                    if (lines.at(lookAhead).contains(QStringLiteral("OpenAI Codex"))) {
                        codexBanner = true;
                        break;
                    }
                    if (lines.at(lookAhead).trimmed().startsWith(QStringLiteral("╰")))
                        break;
                }
                if (codexBanner) {
                    skippingBanner = true;
                    continue;
                }
            }

            if (skippingBanner) {
                if (trimmed.startsWith(QStringLiteral("╰")))
                    skippingBanner = false;
                continue;
            }

            if (statusPattern.match(lines.at(i)).hasMatch())
                continue;

            QString promptCandidate = trimmed;
            if (promptCandidate.startsWith(QStringLiteral("›")))
                promptCandidate = promptCandidate.mid(1).trimmed();
            const bool placeholder = promptCandidate == QStringLiteral("Summarize recent commits")
                || promptCandidate == QStringLiteral("Write tests for @filename")
                || promptCandidate == QStringLiteral("Improve documentation in @filename")
                || promptCandidate == QStringLiteral("Implement {feature}")
                || promptCandidate.contains(QStringLiteral("@filename"))
                || promptCandidate.contains(QStringLiteral("{feature}"));
            if (placeholder)
                continue;

            if (trimmed.startsWith(QStringLiteral("Tip:"))
                || (trimmed.startsWith(QStringLiteral("• You have"))
                    && trimmed.contains(QStringLiteral("usage limit"),
                                        Qt::CaseInsensitive))) {
                continue;
            }

            if (trimmed.isEmpty()) {
                if (!cleanedLines.isEmpty() && !cleanedLines.constLast().trimmed().isEmpty())
                    cleanedLines.append(QString());
                continue;
            }
            cleanedLines.append(lines.at(i));
        }
        lines = cleanedLines;
    }

    while (!lines.isEmpty() && lines.constLast().trimmed().isEmpty())
        lines.removeLast();
    output = lines.join(u'\n');
    if (!output.isEmpty())
        output.append(u'\n');
    return {output, modelName};
}

} // namespace

AgentTerminalService::AgentTerminalService(QObject *parent)
    : QObject(parent)
    , refreshTimer_(new QTimer(this)) {
    refreshTimer_->setInterval(300);
    connect(refreshTimer_, &QTimer::timeout, this, &AgentTerminalService::refreshSessions);
    loadProjects();
    discoverSessions();
    refreshTimer_->start();
}

QVariantList AgentTerminalService::sessions() const {
    QVariantList result;
    result.reserve(sessions_.size());
    for (const auto &session : sessions_) {
        result.append(QVariantMap{
            {QStringLiteral("id"), session.id},
            {QStringLiteral("projectId"), session.projectId},
            {QStringLiteral("provider"), session.provider},
            {QStringLiteral("label"), session.label},
            {QStringLiteral("workingDirectory"), session.workingDirectory},
            {QStringLiteral("model"), session.modelName},
            {QStringLiteral("running"), session.running},
        });
    }
    return result;
}

QVariantList AgentTerminalService::projects() const {
    QVariantList result;
    result.reserve(projects_.size());
    for (const auto &project : projects_) {
        result.append(QVariantMap{
            {QStringLiteral("id"), project.id},
            {QStringLiteral("name"), project.name},
            {QStringLiteral("workingDirectory"), project.workingDirectory},
        });
    }
    return result;
}

bool AgentTerminalService::available() const {
    return !QStandardPaths::findExecutable(QStringLiteral("tmux")).isEmpty();
}

QString AgentTerminalService::createSession(const QString &requestedProvider,
                                            const QString &requestedDirectory) {
    const QString projectId = projects_.isEmpty() ? QString() : projects_.constFirst().id;
    QString workingDirectory = requestedDirectory;
    if (workingDirectory.isEmpty() && !projects_.isEmpty())
        workingDirectory = projects_.constFirst().workingDirectory;
    const QString provider = normalizedProvider(requestedProvider);
    if (projectId.isEmpty())
        return {};
    const int projectIndex = [&]() {
        for (int i = 0; i < projects_.size(); ++i)
            if (projects_[i].id == projectId) return i;
        return -1;
    }();
    if (projectIndex < 0)
        return {};

    // Preserve the original API for callers outside Agent Workspace.
    if (!requestedDirectory.isEmpty() && QDir(requestedDirectory).exists())
        workingDirectory = requestedDirectory;
    return createSessionForProject(projectId, provider);
}

QString AgentTerminalService::createSessionForProject(const QString &projectId,
                                                      const QString &requestedProvider) {
    const QString provider = normalizedProvider(requestedProvider);
    if (provider.isEmpty()) {
        emit errorOccurred(QStringLiteral("Unknown terminal type: %1").arg(requestedProvider));
        return {};
    }
    if (!available()) {
        emit errorOccurred(QStringLiteral("tmux is required for Agent Workspace"));
        return {};
    }

    const QString executable = executableForProvider(provider);
    if (executable.isEmpty()) {
        emit errorOccurred(QStringLiteral("%1 is not installed").arg(displayProvider(provider)));
        return {};
    }

    QString workingDirectory;
    for (const auto &project : projects_) {
        if (project.id == projectId) {
            workingDirectory = project.workingDirectory;
            break;
        }
    }
    if (workingDirectory.isEmpty()) {
        emit errorOccurred(QStringLiteral("Project no longer exists"));
        return {};
    }

    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString tmuxName = QStringLiteral("%1-%2").arg(provider, id);
    const QString label = nextLabel(provider, projectId);

    QStringList arguments{
        QStringLiteral("new-session"), QStringLiteral("-d"),
        QStringLiteral("-x"), QStringLiteral("140"),
        QStringLiteral("-y"), QStringLiteral("38"),
        QStringLiteral("-s"), tmuxName,
        QStringLiteral("-c"), workingDirectory,
        executable,
    };
    if (provider == QStringLiteral("shell"))
        arguments.append(QStringLiteral("--login"));

    int serverExitCode = -1;
    runTmux({QStringLiteral("has-session")}, {}, &serverExitCode);

    int exitCode = -1;
    const QByteArray error = serverExitCode == 0
        ? runTmux(arguments, {}, &exitCode)
        : startPersistentTmux(id, arguments, &exitCode);
    if (exitCode != 0) {
        emit errorOccurred(QStringLiteral("Could not start %1: %2")
                               .arg(displayProvider(provider), QString::fromUtf8(error).trimmed()));
        return {};
    }

    runTmux({QStringLiteral("set-option"), QStringLiteral("-t"), tmuxName,
             QStringLiteral("remain-on-exit"), QStringLiteral("on")});
    runTmux({QStringLiteral("set-option"), QStringLiteral("-t"), tmuxName,
             QStringLiteral("status"), QStringLiteral("off")});
    runTmux({QStringLiteral("set-option"), QStringLiteral("-t"), tmuxName,
             QStringLiteral("mouse"), QStringLiteral("on")});

    sessions_.append({id, projectId, provider, label, tmuxName, workingDirectory, {}, {}, true});
    emit sessionsChanged();
    refreshSessions();
    return id;
}

QString AgentTerminalService::createProject() {
    AgentProject project;
    project.id = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    project.name = QStringLiteral("Project %1").arg(projects_.size() + 1);
    project.workingDirectory = QDir::homePath();
    projects_.append(project);
    saveProjects();
    emit projectsChanged();
    return project.id;
}

void AgentTerminalService::renameProject(const QString &projectId, const QString &requestedName) {
    const QString name = requestedName.trimmed();
    if (name.isEmpty())
        return;
    for (auto &project : projects_) {
        if (project.id == projectId && project.name != name) {
            project.name = name;
            saveProjects();
            emit projectsChanged();
            return;
        }
    }
}

void AgentTerminalService::stopSession(const QString &id) {
    const int index = indexForId(id);
    if (index < 0)
        return;

    runTmux({QStringLiteral("kill-session"), QStringLiteral("-t"), sessions_[index].tmuxName});
    sessions_.removeAt(index);
    emit sessionsChanged();
}

void AgentTerminalService::sendText(const QString &id, const QString &text) {
    const int index = indexForId(id);
    if (index < 0 || text.isEmpty())
        return;
    runTmux({QStringLiteral("send-keys"), QStringLiteral("-t"), sessions_[index].tmuxName,
             QStringLiteral("-l"), QStringLiteral("--"), text});
}

void AgentTerminalService::submitText(const QString &id, const QString &text) {
    if (indexForId(id) < 0 || text.isEmpty())
        return;

    sendText(id, text);
    // Interactive agent TUIs deliberately detect rapidly arriving characters
    // as a paste. Give that paste a moment to settle before pressing Enter, or
    // the Enter is folded into the pasted draft instead of submitting it.
    QTimer::singleShot(180, this, [this, id]() {
        if (indexForId(id) >= 0)
            sendKey(id, QStringLiteral("Enter"));
    });
}

void AgentTerminalService::sendKey(const QString &id, const QString &key) {
    const int index = indexForId(id);
    if (index < 0 || key.isEmpty())
        return;
    runTmux({QStringLiteral("send-keys"), QStringLiteral("-t"), sessions_[index].tmuxName,
             key});
}

void AgentTerminalService::pasteClipboard(const QString &id) {
    const auto *clipboard = QGuiApplication::clipboard();
    if (clipboard)
        sendText(id, clipboard->text());
}

void AgentTerminalService::resizeSession(const QString &id, int columns, int rows) {
    const int index = indexForId(id);
    if (index < 0)
        return;
    columns = qBound(40, columns, 240);
    rows = qBound(10, rows, 80);
    runTmux({QStringLiteral("resize-window"), QStringLiteral("-t"), sessions_[index].tmuxName,
             QStringLiteral("-x"), QString::number(columns),
             QStringLiteral("-y"), QString::number(rows)});
}

QString AgentTerminalService::outputForSession(const QString &id) const {
    const int index = indexForId(id);
    return index >= 0 ? sessions_[index].output : QString();
}

void AgentTerminalService::discoverSessions() {
    if (!available())
        return;

    int exitCode = -1;
    const QString output = QString::fromUtf8(runTmux(
        {QStringLiteral("list-sessions"), QStringLiteral("-F"), QStringLiteral("#{session_name}")},
        {}, &exitCode));
    if (exitCode != 0)
        return;

    const QRegularExpression namePattern(QStringLiteral("^(codex|claude|shell)-([a-zA-Z0-9]+)$"));
    const auto names = output.split(u'\n', Qt::SkipEmptyParts);
    for (const QString &name : names) {
        const auto match = namePattern.match(name.trimmed());
        if (!match.hasMatch() || indexForTmuxName(name.trimmed()) >= 0)
            continue;
        const QString provider = match.captured(1);
        const QString id = match.captured(2);
        const QString projectId = projects_.constFirst().id;
        sessions_.append({id, projectId, provider, nextLabel(provider, projectId), name.trimmed(),
                          projects_.constFirst().workingDirectory, {}, {}, true});
    }
    if (!sessions_.isEmpty()) {
        emit sessionsChanged();
        refreshSessions();
    }
}

void AgentTerminalService::refreshSessions() {
    bool metadataChanged = false;
    for (auto &session : sessions_) {
        int statusExitCode = -1;
        const QString dead = QString::fromUtf8(runTmux(
            {QStringLiteral("display-message"), QStringLiteral("-p"),
             QStringLiteral("-t"), session.tmuxName, QStringLiteral("#{pane_dead}")},
            {}, &statusExitCode)).trimmed();
        const bool running = statusExitCode == 0 && dead != QStringLiteral("1");
        if (session.running != running) {
            session.running = running;
            metadataChanged = true;
        }

        if (statusExitCode != 0)
            continue;
        const auto capture = cleanCapturedPane(QString::fromUtf8(runTmux(
            {QStringLiteral("capture-pane"), QStringLiteral("-p"), QStringLiteral("-J"),
             QStringLiteral("-t"), session.tmuxName, QStringLiteral("-S"), QStringLiteral("-120")})),
                                                session.provider);
        if (!capture.modelName.isEmpty() && session.modelName != capture.modelName) {
            session.modelName = capture.modelName;
            metadataChanged = true;
        }
        if (session.output != capture.output) {
            session.output = capture.output;
            emit sessionOutputChanged(session.id, session.output);
        }
    }
    if (metadataChanged)
        emit sessionsChanged();
}

int AgentTerminalService::indexForId(const QString &id) const {
    for (int i = 0; i < sessions_.size(); ++i) {
        if (sessions_[i].id == id)
            return i;
    }
    return -1;
}

int AgentTerminalService::indexForTmuxName(const QString &name) const {
    for (int i = 0; i < sessions_.size(); ++i) {
        if (sessions_[i].tmuxName == name)
            return i;
    }
    return -1;
}

QString AgentTerminalService::executableForProvider(const QString &provider) const {
    if (provider == QStringLiteral("shell"))
        return QStandardPaths::findExecutable(QStringLiteral("bash"));
    return QStandardPaths::findExecutable(provider);
}

QString AgentTerminalService::nextLabel(const QString &provider, const QString &projectId) const {
    int count = 0;
    for (const auto &session : sessions_) {
        if (session.provider == provider && session.projectId == projectId)
            ++count;
    }
    return QStringLiteral("%1 %2").arg(displayProvider(provider)).arg(count + 1);
}

void AgentTerminalService::loadProjects() {
    QFile file(projectConfigPath());
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonArray array = QJsonDocument::fromJson(file.readAll())
                                     .object().value(QStringLiteral("projects")).toArray();
        for (const auto &value : array) {
            const QJsonObject object = value.toObject();
            AgentProject project{
                object.value(QStringLiteral("id")).toString(),
                object.value(QStringLiteral("name")).toString(),
                object.value(QStringLiteral("workingDirectory")).toString(),
            };
            if (!project.id.isEmpty() && !project.name.isEmpty()) {
                if (!QDir(project.workingDirectory).exists())
                    project.workingDirectory = QDir::homePath();
                projects_.append(project);
            }
        }
    }
    if (projects_.isEmpty()) {
        projects_.append({QStringLiteral("home"), QStringLiteral("Home"), QDir::homePath()});
        saveProjects();
    }
}

void AgentTerminalService::saveProjects() const {
    QJsonArray array;
    for (const auto &project : projects_) {
        array.append(QJsonObject{
            {QStringLiteral("id"), project.id},
            {QStringLiteral("name"), project.name},
            {QStringLiteral("workingDirectory"), project.workingDirectory},
        });
    }
    QFile file(projectConfigPath());
    if (file.open(QIODevice::WriteOnly))
        file.write(QJsonDocument(QJsonObject{{QStringLiteral("version"), 1},
                                             {QStringLiteral("projects"), array}})
                       .toJson(QJsonDocument::Indented));
}

QString AgentTerminalService::projectConfigPath() const {
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/ciderdeck");
    QDir().mkpath(directory);
    return directory + QStringLiteral("/agent-workspace.json");
}

QByteArray AgentTerminalService::runTmux(const QStringList &arguments, const QByteArray &input,
                                         int *exitCode) const {
    QProcess process;
    process.setProgram(QStringLiteral("tmux"));
    process.setArguments(QStringList{QStringLiteral("-L"), QStringLiteral("ciderdeck")} + arguments);
    process.start();
    if (!process.waitForStarted(1000)) {
        if (exitCode)
            *exitCode = -1;
        return process.errorString().toUtf8();
    }
    if (!input.isEmpty()) {
        process.write(input);
        process.closeWriteChannel();
    }
    if (!process.waitForFinished(1500)) {
        process.kill();
        process.waitForFinished();
    }
    if (exitCode)
        *exitCode = process.exitCode();
    const QByteArray standardOutput = process.readAllStandardOutput();
    const QByteArray standardError = process.readAllStandardError();
    return standardOutput.isEmpty() ? standardError : standardOutput;
}

QByteArray AgentTerminalService::startPersistentTmux(const QString &unitSuffix,
                                                     const QStringList &arguments,
                                                     int *exitCode) const {
    const QString systemdRun = QStandardPaths::findExecutable(QStringLiteral("systemd-run"));
    if (systemdRun.isEmpty())
        return runTmux(arguments, {}, exitCode);

    QProcess process;
    process.setProgram(systemdRun);
    QStringList systemdArguments{
        QStringLiteral("--user"), QStringLiteral("--scope"),
        QStringLiteral("--quiet"), QStringLiteral("--collect"),
        QStringLiteral("--unit=ciderdeck-agent-terminals-%1").arg(unitSuffix),
        QStringLiteral("tmux"), QStringLiteral("-L"), QStringLiteral("ciderdeck"),
    };
    systemdArguments.append(arguments);
    process.setArguments(systemdArguments);
    process.start();
    if (!process.waitForStarted(1000)) {
        if (exitCode)
            *exitCode = -1;
        return process.errorString().toUtf8();
    }
    if (!process.waitForFinished(2000)) {
        process.kill();
        process.waitForFinished();
    }
    if (exitCode)
        *exitCode = process.exitCode();
    const QByteArray standardOutput = process.readAllStandardOutput();
    const QByteArray standardError = process.readAllStandardError();
    return standardOutput.isEmpty() ? standardError : standardOutput;
}

} // namespace ciderdeck
