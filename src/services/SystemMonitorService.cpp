#include "SystemMonitorService.h"

#include <QFile>
#include <QTextStream>

namespace ciderdeck {

SystemMonitorService::SystemMonitorService(QObject *parent)
    : QObject(parent)
    , timer_(new QTimer(this)) {
    timer_->setInterval(2000);
    connect(timer_, &QTimer::timeout, this, &SystemMonitorService::poll);
    timer_->start();
    poll();
}

void SystemMonitorService::poll() {
    readCpu();
    readMemory();
    emit updated();
}

void SystemMonitorService::readCpu() {
    QFile file("/proc/stat");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QTextStream stream(&file);
    QString line = stream.readLine();
    if (!line.startsWith("cpu ")) return;

    auto parts = line.split(' ', Qt::SkipEmptyParts);
    if (parts.size() < 5) return;

    long long user = parts[1].toLongLong();
    long long nice = parts[2].toLongLong();
    long long system = parts[3].toLongLong();
    long long idle = parts[4].toLongLong();
    long long iowait = parts.size() > 5 ? parts[5].toLongLong() : 0;

    long long total = user + nice + system + idle + iowait;
    if (parts.size() > 6) total += parts[6].toLongLong(); // irq
    if (parts.size() > 7) total += parts[7].toLongLong(); // softirq

    long long totalDiff = total - prevTotal_;
    long long idleDiff = idle - prevIdle_;

    if (totalDiff > 0) {
        cpuPercent_ = 100.0 * (1.0 - static_cast<double>(idleDiff) / totalDiff);
    }

    prevTotal_ = total;
    prevIdle_ = idle;
}

void SystemMonitorService::readMemory() {
    QFile file("/proc/meminfo");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QTextStream stream(&file);
    long long memTotal = 0, memAvailable = 0;

    while (!stream.atEnd()) {
        QString line = stream.readLine();
        if (line.startsWith("MemTotal:")) {
            memTotal = line.split(' ', Qt::SkipEmptyParts)[1].toLongLong();
        } else if (line.startsWith("MemAvailable:")) {
            memAvailable = line.split(' ', Qt::SkipEmptyParts)[1].toLongLong();
        }
        if (memTotal > 0 && memAvailable > 0) break;
    }

    if (memTotal > 0) {
        long long used = memTotal - memAvailable;
        ramPercent_ = 100.0 * static_cast<double>(used) / memTotal;
        ramUsed_ = QString::number(used / 1024.0 / 1024.0, 'f', 1) + " GB";
        ramTotal_ = QString::number(memTotal / 1024.0 / 1024.0, 'f', 1) + " GB";
    }
}

} // namespace ciderdeck
