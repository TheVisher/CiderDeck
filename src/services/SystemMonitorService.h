#pragma once

#include <QObject>
#include <QTimer>

namespace ciderdeck {

class SystemMonitorService : public QObject {
    Q_OBJECT
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY updated)
    Q_PROPERTY(double ramPercent READ ramPercent NOTIFY updated)
    Q_PROPERTY(QString ramUsed READ ramUsed NOTIFY updated)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY updated)

public:
    explicit SystemMonitorService(QObject *parent = nullptr);

    double cpuPercent() const { return cpuPercent_; }
    double ramPercent() const { return ramPercent_; }
    QString ramUsed() const { return ramUsed_; }
    QString ramTotal() const { return ramTotal_; }

signals:
    void updated();

private:
    void poll();
    void readCpu();
    void readMemory();

    QTimer *timer_ = nullptr;
    double cpuPercent_ = 0.0;
    double ramPercent_ = 0.0;
    QString ramUsed_;
    QString ramTotal_;

    // CPU tracking
    long long prevIdle_ = 0;
    long long prevTotal_ = 0;
};

} // namespace ciderdeck
