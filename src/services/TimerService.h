#pragma once

#include <QObject>
#include <QTimer>

namespace ciderdeck {

class TimerService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(int remainingMs READ remainingMs NOTIFY tick)
    Q_PROPERTY(int elapsedMs READ elapsedMs NOTIFY tick)
    Q_PROPERTY(QString displayTime READ displayTime NOTIFY tick)

public:
    explicit TimerService(QObject *parent = nullptr);

    QString mode() const { return mode_; }
    QString state() const { return state_; }
    int remainingMs() const { return remainingMs_; }
    int elapsedMs() const { return elapsedMs_; }
    QString displayTime() const;

    void setMode(const QString &mode);

    Q_INVOKABLE void setDuration(int seconds);
    Q_INVOKABLE void start();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void addTime(int seconds);

signals:
    void modeChanged();
    void stateChanged();
    void tick();
    void finished();

private:
    void onTick();

    QTimer *tickTimer_ = nullptr;
    QString mode_ = "timer";     // "timer" or "stopwatch"
    QString state_ = "idle";     // "idle", "running", "paused", "finished"
    int durationMs_ = 5 * 60 * 1000;
    int remainingMs_ = 5 * 60 * 1000;
    int elapsedMs_ = 0;
};

} // namespace ciderdeck
