#pragma once

#include <QObject>
#include <QByteArray>
#include <QStringList>

#include <array>

class QProcess;
class QSocketNotifier;
class QTimer;

namespace ciderdeck {

class UpdateService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool checking READ checking NOTIFY updated)
    Q_PROPERTY(bool hasChecked READ hasChecked NOTIFY updated)
    Q_PROPERTY(bool updateRunning READ updateRunning NOTIFY updated)
    Q_PROPERTY(bool terminalActive READ terminalActive NOTIFY updated)
    Q_PROPERTY(QString terminalOutput READ terminalOutput NOTIFY terminalOutputChanged)
    Q_PROPERTY(int officialCount READ officialCount NOTIFY updated)
    Q_PROPERTY(int aurCount READ aurCount NOTIFY updated)
    Q_PROPERTY(int flatpakCount READ flatpakCount NOTIFY updated)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY updated)
    Q_PROPERTY(QStringList officialUpdates READ officialUpdates NOTIFY updated)
    Q_PROPERTY(QStringList aurUpdates READ aurUpdates NOTIFY updated)
    Q_PROPERTY(QStringList flatpakUpdates READ flatpakUpdates NOTIFY updated)
    Q_PROPERTY(QStringList allUpdates READ allUpdates NOTIFY updated)
    Q_PROPERTY(QString lastChecked READ lastChecked NOTIFY updated)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY updated)

public:
    explicit UpdateService(QObject *parent = nullptr);
    ~UpdateService() override;

    bool checking() const { return checking_; }
    bool hasChecked() const { return hasChecked_; }
    bool updateRunning() const;
    bool terminalActive() const { return terminalActive_; }
    QString terminalOutput() const { return terminalOutput_; }
    int officialCount() const { return officialUpdates_.size(); }
    int aurCount() const { return aurUpdates_.size(); }
    int flatpakCount() const { return flatpakUpdates_.size(); }
    int totalCount() const { return officialCount() + aurCount() + flatpakCount(); }
    QStringList officialUpdates() const { return officialUpdates_; }
    QStringList aurUpdates() const { return aurUpdates_; }
    QStringList flatpakUpdates() const { return flatpakUpdates_; }
    QStringList allUpdates() const;
    QString lastChecked() const { return lastChecked_; }
    QString errorMessage() const { return errors_.join(QStringLiteral(" · ")); }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void updateAll();
    Q_INVOKABLE void sendTerminalInput(const QString &input);
    Q_INVOKABLE void cancelUpdate();
    Q_INVOKABLE void setTerminalSize(int columns, int rows);

    static QString sanitizeTerminalOutput(const QByteArray &output);

signals:
    void updated();
    void terminalOutputChanged();

private:
    enum class Source { Official = 0, Aur = 1, Flatpak = 2 };

    void startCheck(Source source, const QString &program, const QStringList &arguments);
    void finishCheck(Source source, int exitCode, bool crashed);
    void failCheck(Source source, const QString &message);
    void completeSource(Source source);
    QString updateCommand() const;
    bool startEmbeddedUpdate(const QString &command);
    void startExternalUpdate(const QString &command);
    void readTerminalOutput();
    void pollTerminalProcess();
    void finishTerminalProcess(int status);
    void closeTerminalDescriptor();
    QProcess *processFor(Source source) const;
    static QString sourceName(Source source);
    static QStringList outputLines(const QByteArray &output);

    QProcess *officialProcess_ = nullptr;
    QProcess *aurProcess_ = nullptr;
    QProcess *flatpakProcess_ = nullptr;
    QProcess *updateProcess_ = nullptr;
    QTimer *refreshTimer_ = nullptr;
    QTimer *timeoutTimer_ = nullptr;
    QTimer *terminalPollTimer_ = nullptr;
    QSocketNotifier *terminalNotifier_ = nullptr;

    int terminalFd_ = -1;
    qint64 terminalPid_ = -1;
    int terminalColumns_ = 90;
    int terminalRows_ = 18;
    bool terminalActive_ = false;
    bool updateCanceled_ = false;
    QByteArray terminalRawOutput_;
    QString terminalOutput_;

    std::array<bool, 3> pending_ = {false, false, false};
    bool checking_ = false;
    bool hasChecked_ = false;
    QStringList officialUpdates_;
    QStringList aurUpdates_;
    QStringList flatpakUpdates_;
    QStringList errors_;
    QString lastChecked_;
};

} // namespace ciderdeck
