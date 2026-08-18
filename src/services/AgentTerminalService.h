#pragma once

#include <QObject>
#include <QVariantList>

class QTimer;

namespace ciderdeck {

struct AgentProject {
    QString id;
    QString name;
    QString workingDirectory;
};

struct AgentTerminalSession {
    QString id;
    QString projectId;
    QString provider;
    QString label;
    QString tmuxName;
    QString workingDirectory;
    QString modelName;
    QString output;
    bool running = true;
};

class AgentTerminalService : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(QVariantList projects READ projects NOTIFY projectsChanged)
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit AgentTerminalService(QObject *parent = nullptr);

    QVariantList sessions() const;
    QVariantList projects() const;
    bool available() const;

    Q_INVOKABLE QString createSession(const QString &provider,
                                      const QString &workingDirectory = QString());
    Q_INVOKABLE QString createSessionForProject(const QString &projectId,
                                                const QString &provider);
    Q_INVOKABLE QString createProject();
    Q_INVOKABLE void renameProject(const QString &projectId, const QString &name);
    Q_INVOKABLE void stopSession(const QString &id);
    Q_INVOKABLE void sendText(const QString &id, const QString &text);
    Q_INVOKABLE void submitText(const QString &id, const QString &text);
    Q_INVOKABLE void sendKey(const QString &id, const QString &key);
    Q_INVOKABLE void pasteClipboard(const QString &id);
    Q_INVOKABLE void resizeSession(const QString &id, int columns, int rows);
    Q_INVOKABLE QString outputForSession(const QString &id) const;

signals:
    void sessionsChanged();
    void projectsChanged();
    void sessionOutputChanged(const QString &id, const QString &output);
    void errorOccurred(const QString &message);

private:
    void loadProjects();
    void saveProjects() const;
    QString projectConfigPath() const;
    void discoverSessions();
    void refreshSessions();
    int indexForId(const QString &id) const;
    int indexForTmuxName(const QString &name) const;
    QString executableForProvider(const QString &provider) const;
    QString nextLabel(const QString &provider, const QString &projectId) const;
    QByteArray runTmux(const QStringList &arguments, const QByteArray &input = {},
                       int *exitCode = nullptr) const;
    QByteArray startPersistentTmux(const QString &unitSuffix, const QStringList &arguments,
                                   int *exitCode = nullptr) const;

    QList<AgentProject> projects_;
    QList<AgentTerminalSession> sessions_;
    QTimer *refreshTimer_ = nullptr;
};

} // namespace ciderdeck
