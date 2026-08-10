#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariantList>

class QProcess;

namespace ciderdeck {

class SystemMonitorService : public QObject {
    Q_OBJECT

    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY updated)
    Q_PROPERTY(double cpuTemp READ cpuTemp NOTIFY updated)
    Q_PROPERTY(double cpuFrequencyGHz READ cpuFrequencyGHz NOTIFY updated)
    Q_PROPERTY(QString cpuName READ cpuName CONSTANT)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY updated)

    Q_PROPERTY(bool gpuAvailable READ gpuAvailable NOTIFY updated)
    Q_PROPERTY(QString gpuName READ gpuName NOTIFY updated)
    Q_PROPERTY(double gpuPercent READ gpuPercent NOTIFY updated)
    Q_PROPERTY(double gpuTemp READ gpuTemp NOTIFY updated)
    Q_PROPERTY(double gpuMemoryPercent READ gpuMemoryPercent NOTIFY updated)
    Q_PROPERTY(QString gpuMemoryUsed READ gpuMemoryUsed NOTIFY updated)
    Q_PROPERTY(QString gpuMemoryTotal READ gpuMemoryTotal NOTIFY updated)
    Q_PROPERTY(double gpuPowerWatts READ gpuPowerWatts NOTIFY updated)
    Q_PROPERTY(double gpuPowerLimit READ gpuPowerLimit NOTIFY updated)
    Q_PROPERTY(double gpuFanPercent READ gpuFanPercent NOTIFY updated)
    Q_PROPERTY(QVariantList gpuHistory READ gpuHistory NOTIFY updated)

    Q_PROPERTY(double ramPercent READ ramPercent NOTIFY updated)
    Q_PROPERTY(QString ramUsed READ ramUsed NOTIFY updated)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY updated)
    Q_PROPERTY(double swapPercent READ swapPercent NOTIFY updated)
    Q_PROPERTY(QString swapUsed READ swapUsed NOTIFY updated)
    Q_PROPERTY(QString swapTotal READ swapTotal NOTIFY updated)
    Q_PROPERTY(QVariantList ramHistory READ ramHistory NOTIFY updated)

    Q_PROPERTY(double storagePercent READ storagePercent NOTIFY updated)
    Q_PROPERTY(QString storageUsed READ storageUsed NOTIFY updated)
    Q_PROPERTY(QString storageTotal READ storageTotal NOTIFY updated)
    Q_PROPERTY(QString storageFree READ storageFree NOTIFY updated)
    Q_PROPERTY(double primaryDriveTemp READ primaryDriveTemp NOTIFY updated)
    Q_PROPERTY(double secondaryDriveTemp READ secondaryDriveTemp NOTIFY updated)
    Q_PROPERTY(QString primaryDriveName READ primaryDriveName CONSTANT)
    Q_PROPERTY(QString secondaryDriveName READ secondaryDriveName CONSTANT)
    Q_PROPERTY(QVariantList storageHistory READ storageHistory NOTIFY updated)

    Q_PROPERTY(QString networkInterface READ networkInterface NOTIFY updated)
    Q_PROPERTY(QString downloadRate READ downloadRate NOTIFY updated)
    Q_PROPERTY(QString uploadRate READ uploadRate NOTIFY updated)
    Q_PROPERTY(double downloadBytesPerSecond READ downloadBytesPerSecond NOTIFY updated)
    Q_PROPERTY(double uploadBytesPerSecond READ uploadBytesPerSecond NOTIFY updated)
    Q_PROPERTY(QVariantList downloadHistory READ downloadHistory NOTIFY updated)
    Q_PROPERTY(QVariantList uploadHistory READ uploadHistory NOTIFY updated)

public:
    explicit SystemMonitorService(QObject *parent = nullptr);

    double cpuPercent() const { return cpuPercent_; }
    double cpuTemp() const { return cpuTemp_; }
    double cpuFrequencyGHz() const { return cpuFrequencyGHz_; }
    QString cpuName() const { return cpuName_; }
    QVariantList cpuHistory() const { return cpuHistory_; }

    bool gpuAvailable() const { return gpuAvailable_; }
    QString gpuName() const { return gpuName_; }
    double gpuPercent() const { return gpuPercent_; }
    double gpuTemp() const { return gpuTemp_; }
    double gpuMemoryPercent() const { return gpuMemoryPercent_; }
    QString gpuMemoryUsed() const { return gpuMemoryUsed_; }
    QString gpuMemoryTotal() const { return gpuMemoryTotal_; }
    double gpuPowerWatts() const { return gpuPowerWatts_; }
    double gpuPowerLimit() const { return gpuPowerLimit_; }
    double gpuFanPercent() const { return gpuFanPercent_; }
    QVariantList gpuHistory() const { return gpuHistory_; }

    double ramPercent() const { return ramPercent_; }
    QString ramUsed() const { return ramUsed_; }
    QString ramTotal() const { return ramTotal_; }
    double swapPercent() const { return swapPercent_; }
    QString swapUsed() const { return swapUsed_; }
    QString swapTotal() const { return swapTotal_; }
    QVariantList ramHistory() const { return ramHistory_; }

    double storagePercent() const { return storagePercent_; }
    QString storageUsed() const { return storageUsed_; }
    QString storageTotal() const { return storageTotal_; }
    QString storageFree() const { return storageFree_; }
    double primaryDriveTemp() const { return primaryDriveTemp_; }
    double secondaryDriveTemp() const { return secondaryDriveTemp_; }
    QString primaryDriveName() const { return primaryDriveName_; }
    QString secondaryDriveName() const { return secondaryDriveName_; }
    QVariantList storageHistory() const { return storageHistory_; }

    QString networkInterface() const { return networkInterface_; }
    QString downloadRate() const { return formatRate(downloadBytesPerSecond_); }
    QString uploadRate() const { return formatRate(uploadBytesPerSecond_); }
    double downloadBytesPerSecond() const { return downloadBytesPerSecond_; }
    double uploadBytesPerSecond() const { return uploadBytesPerSecond_; }
    QVariantList downloadHistory() const { return downloadHistory_; }
    QVariantList uploadHistory() const { return uploadHistory_; }

    Q_INVOKABLE void setConsumerActive(QObject *consumer, bool active);

signals:
    void updated();

protected:
    virtual void poll();

private:
    void consumerDestroyed(QObject *consumer);
    void readCpu();
    void readCpuDetails();
    void readMemory();
    void readStorage();
    void readNetwork();
    void requestGpu();
    void parseGpuOutput();
    void readHardwareNames();
    static QString formatBytes(double bytes);
    static QString formatRate(double bytesPerSecond);
    static void appendHistory(QVariantList &history, double value);

    QTimer *timer_ = nullptr;
    QProcess *gpuProcess_ = nullptr;
    QElapsedTimer networkTimer_;
    QSet<QObject *> activeConsumers_;
    QSet<QObject *> trackedConsumers_;

    double cpuPercent_ = 0.0;
    double cpuTemp_ = 0.0;
    double cpuFrequencyGHz_ = 0.0;
    QString cpuName_;
    QVariantList cpuHistory_;
    long long prevIdle_ = 0;
    long long prevTotal_ = 0;

    bool gpuAvailable_ = false;
    QString gpuName_;
    double gpuPercent_ = 0.0;
    double gpuTemp_ = 0.0;
    double gpuMemoryPercent_ = 0.0;
    QString gpuMemoryUsed_;
    QString gpuMemoryTotal_;
    double gpuPowerWatts_ = 0.0;
    double gpuPowerLimit_ = 0.0;
    double gpuFanPercent_ = 0.0;
    QVariantList gpuHistory_;

    double ramPercent_ = 0.0;
    QString ramUsed_;
    QString ramTotal_;
    double swapPercent_ = 0.0;
    QString swapUsed_;
    QString swapTotal_;
    QVariantList ramHistory_;

    double storagePercent_ = 0.0;
    QString storageUsed_;
    QString storageTotal_;
    QString storageFree_;
    double primaryDriveTemp_ = 0.0;
    double secondaryDriveTemp_ = 0.0;
    QString primaryDriveName_;
    QString secondaryDriveName_;
    QVariantList storageHistory_;

    QString networkInterface_;
    quint64 previousRxBytes_ = 0;
    quint64 previousTxBytes_ = 0;
    double downloadBytesPerSecond_ = 0.0;
    double uploadBytesPerSecond_ = 0.0;
    QVariantList downloadHistory_;
    QVariantList uploadHistory_;
};

} // namespace ciderdeck
