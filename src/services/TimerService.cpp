#include "TimerService.h"

namespace ciderdeck {

TimerService::TimerService(QObject *parent)
    : QObject(parent)
    , tickTimer_(new QTimer(this)) {
    tickTimer_->setInterval(100);
    connect(tickTimer_, &QTimer::timeout, this, &TimerService::onTick);
}

void TimerService::setMode(const QString &mode) {
    if (mode_ != mode && (mode == "timer" || mode == "stopwatch")) {
        mode_ = mode;
        reset();
        emit modeChanged();
    }
}

void TimerService::setDuration(int seconds) {
    durationMs_ = seconds * 1000;
    if (state_ == "idle") {
        remainingMs_ = durationMs_;
        emit tick();
    }
}

void TimerService::start() {
    if (state_ == "finished") reset();
    state_ = "running";
    tickTimer_->start();
    emit stateChanged();
}

void TimerService::pause() {
    if (state_ != "running") return;
    state_ = "paused";
    tickTimer_->stop();
    emit stateChanged();
}

void TimerService::reset() {
    tickTimer_->stop();
    state_ = "idle";
    elapsedMs_ = 0;
    remainingMs_ = durationMs_;
    emit stateChanged();
    emit tick();
}

void TimerService::addTime(int seconds) {
    if (mode_ == "timer") {
        remainingMs_ += seconds * 1000;
        durationMs_ += seconds * 1000;
        if (state_ == "finished") {
            state_ = "running";
            tickTimer_->start();
            emit stateChanged();
        }
        emit tick();
    }
}

void TimerService::onTick() {
    if (mode_ == "timer") {
        remainingMs_ -= 100;
        if (remainingMs_ <= 0) {
            remainingMs_ = 0;
            state_ = "finished";
            tickTimer_->stop();
            emit stateChanged();
            emit finished();
        }
    } else {
        elapsedMs_ += 100;
    }
    emit tick();
}

QString TimerService::displayTime() const {
    int ms = (mode_ == "timer") ? remainingMs_ : elapsedMs_;
    int totalSeconds = ms / 1000;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    return QStringLiteral("%1:%2").arg(minutes, 2, 10, QLatin1Char('0'))
                                  .arg(seconds, 2, 10, QLatin1Char('0'));
}

} // namespace ciderdeck
