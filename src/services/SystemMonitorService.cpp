#include "SystemMonitorService.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStorageInfo>
#include <QTextStream>

namespace ciderdeck {

namespace {

double readTemperature(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return 0.0;
    bool ok = false;
    const double value = QString::fromUtf8(file.readAll()).trimmed().toDouble(&ok);
    return ok ? value / 1000.0 : 0.0;
}

QString readTrimmed(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

} // namespace

SystemMonitorService::SystemMonitorService(QObject *parent)
    : QObject(parent)
    , timer_(new QTimer(this))
    , gpuProcess_(new QProcess(this)) {
    timer_->setInterval(2000);
    connect(timer_, &QTimer::timeout, this, &SystemMonitorService::poll);
    connect(gpuProcess_, &QProcess::finished, this, &SystemMonitorService::parseGpuOutput);

    readHardwareNames();
    networkTimer_.start();
    poll();
    timer_->start();
}

void SystemMonitorService::poll() {
    readCpu();
    readCpuDetails();
    readMemory();
    readStorage();
    readNetwork();
    requestGpu();

    appendHistory(cpuHistory_, cpuPercent_);
    appendHistory(ramHistory_, ramPercent_);
    appendHistory(storageHistory_, storagePercent_);
    appendHistory(downloadHistory_, downloadBytesPerSecond_);
    appendHistory(uploadHistory_, uploadBytesPerSecond_);
    emit updated();
}

void SystemMonitorService::readHardwareNames() {
    QFile cpuInfo(QStringLiteral("/proc/cpuinfo"));
    if (cpuInfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
        for (;;) {
            const QString line = QString::fromUtf8(cpuInfo.readLine());
            if (line.isEmpty())
                break;
            if (line.startsWith(QStringLiteral("model name"))) {
                cpuName_ = line.section(':', 1).trimmed();
                cpuName_.remove(QStringLiteral(" Processor"));
                break;
            }
        }
    }
    primaryDriveName_ = readTrimmed(QStringLiteral("/sys/class/nvme/nvme0/model"));
    secondaryDriveName_ = readTrimmed(QStringLiteral("/sys/class/nvme/nvme1/model"));
}

void SystemMonitorService::readCpu() {
    QFile file(QStringLiteral("/proc/stat"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const auto parts = QString::fromUtf8(file.readLine()).split(' ', Qt::SkipEmptyParts);
    if (parts.size() < 5 || parts[0] != QStringLiteral("cpu"))
        return;

    const long long user = parts[1].toLongLong();
    const long long nice = parts[2].toLongLong();
    const long long system = parts[3].toLongLong();
    const long long idle = parts[4].toLongLong();
    const long long iowait = parts.size() > 5 ? parts[5].toLongLong() : 0;
    long long total = user + nice + system + idle + iowait;
    for (int i = 6; i < qMin(parts.size(), 9); ++i)
        total += parts[i].toLongLong();

    const long long totalDiff = total - prevTotal_;
    const long long idleDiff = idle + iowait - prevIdle_;
    if (prevTotal_ > 0 && totalDiff > 0)
        cpuPercent_ = qBound(0.0, 100.0 * (1.0 - static_cast<double>(idleDiff) / totalDiff), 100.0);
    prevTotal_ = total;
    prevIdle_ = idle + iowait;
}

void SystemMonitorService::readCpuDetails() {
    QDir hwmon(QStringLiteral("/sys/class/hwmon"));
    const QStringList entries = hwmon.entryList({QStringLiteral("hwmon*")}, QDir::Dirs | QDir::NoDotAndDotDot);
    primaryDriveTemp_ = 0.0;
    secondaryDriveTemp_ = 0.0;

    for (const QString &entry : entries) {
        const QString base = hwmon.filePath(entry);
        const QString name = readTrimmed(base + QStringLiteral("/name"));
        if (name == QStringLiteral("k10temp")) {
            cpuTemp_ = readTemperature(base + QStringLiteral("/temp1_input"));
        } else if (name == QStringLiteral("nvme")) {
            const QString devicePath = QFileInfo(base + QStringLiteral("/device")).canonicalFilePath();
            const double temp = readTemperature(base + QStringLiteral("/temp1_input"));
            if (devicePath.contains(QStringLiteral("/nvme/nvme0")))
                primaryDriveTemp_ = temp;
            else if (devicePath.contains(QStringLiteral("/nvme/nvme1")))
                secondaryDriveTemp_ = temp;
        }
    }

    QDir cpuDir(QStringLiteral("/sys/devices/system/cpu"));
    const QStringList cpus = cpuDir.entryList({QStringLiteral("cpu[0-9]*")}, QDir::Dirs | QDir::NoDotAndDotDot);
    double totalKhz = 0.0;
    int count = 0;
    for (const QString &cpu : cpus) {
        QFile freq(cpuDir.filePath(cpu + QStringLiteral("/cpufreq/scaling_cur_freq")));
        if (freq.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool ok = false;
            const double khz = QString::fromUtf8(freq.readAll()).trimmed().toDouble(&ok);
            if (ok) {
                totalKhz += khz;
                ++count;
            }
        }
    }
    cpuFrequencyGHz_ = count > 0 ? totalKhz / count / 1000000.0 : 0.0;
}

void SystemMonitorService::readMemory() {
    QFile file(QStringLiteral("/proc/meminfo"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    qint64 memTotal = 0;
    qint64 memAvailable = 0;
    qint64 swapTotal = 0;
    qint64 swapFree = 0;
    for (;;) {
        const QByteArray line = file.readLine();
        if (line.isEmpty())
            break;
        const auto fields = line.simplified().split(' ');
        const qint64 value = fields.size() > 1 ? fields[1].toLongLong() * 1024 : 0;
        if (line.startsWith("MemTotal:")) memTotal = value;
        else if (line.startsWith("MemAvailable:")) memAvailable = value;
        else if (line.startsWith("SwapTotal:")) swapTotal = value;
        else if (line.startsWith("SwapFree:")) swapFree = value;
    }

    if (memTotal > 0) {
        const qint64 used = memTotal - memAvailable;
        ramPercent_ = 100.0 * static_cast<double>(used) / memTotal;
        ramUsed_ = formatBytes(used);
        ramTotal_ = formatBytes(memTotal);
    }
    const qint64 swapUsed = qMax<qint64>(0, swapTotal - swapFree);
    swapPercent_ = swapTotal > 0 ? 100.0 * static_cast<double>(swapUsed) / swapTotal : 0.0;
    swapUsed_ = formatBytes(swapUsed);
    swapTotal_ = formatBytes(swapTotal);
}

void SystemMonitorService::readStorage() {
    const QStorageInfo root = QStorageInfo::root();
    const qint64 total = root.bytesTotal();
    const qint64 free = root.bytesAvailable();
    if (total <= 0)
        return;
    const qint64 used = total - free;
    storagePercent_ = 100.0 * static_cast<double>(used) / total;
    storageUsed_ = formatBytes(used);
    storageTotal_ = formatBytes(total);
    storageFree_ = formatBytes(free);
}

void SystemMonitorService::readNetwork() {
    QString selected;
    quint64 rx = 0;
    quint64 tx = 0;
    QDir networkDir(QStringLiteral("/sys/class/net"));
    const QStringList interfaces = networkDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &iface : interfaces) {
        if (iface == QStringLiteral("lo"))
            continue;
        const QString operState = readTrimmed(QStringLiteral("/sys/class/net/%1/operstate").arg(iface));
        if (operState != QStringLiteral("up"))
            continue;
        selected = iface;
        rx = readTrimmed(QStringLiteral("/sys/class/net/%1/statistics/rx_bytes").arg(iface)).toULongLong();
        tx = readTrimmed(QStringLiteral("/sys/class/net/%1/statistics/tx_bytes").arg(iface)).toULongLong();
        break;
    }

    const qint64 elapsedMs = networkTimer_.restart();
    if (networkInterface_ != selected)
        qInfo() << "[SystemMonitor] Active network interface:" << (selected.isEmpty() ? "none" : selected);
    if (selected == networkInterface_ && previousRxBytes_ > 0 && elapsedMs > 0) {
        downloadBytesPerSecond_ = (rx - previousRxBytes_) * 1000.0 / elapsedMs;
        uploadBytesPerSecond_ = (tx - previousTxBytes_) * 1000.0 / elapsedMs;
    } else {
        downloadBytesPerSecond_ = 0.0;
        uploadBytesPerSecond_ = 0.0;
    }
    networkInterface_ = selected;
    previousRxBytes_ = rx;
    previousTxBytes_ = tx;
}

void SystemMonitorService::requestGpu() {
    if (gpuProcess_->state() != QProcess::NotRunning)
        return;
    gpuProcess_->start(QStringLiteral("nvidia-smi"), {
        QStringLiteral("--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,fan.speed"),
        QStringLiteral("--format=csv,noheader,nounits")
    });
}

void SystemMonitorService::parseGpuOutput() {
    const QString output = QString::fromUtf8(gpuProcess_->readAllStandardOutput()).trimmed();
    const auto fields = output.split(',', Qt::KeepEmptyParts);
    if (fields.size() < 8) {
        gpuAvailable_ = false;
        emit updated();
        return;
    }

    gpuAvailable_ = true;
    gpuName_ = fields[0].trimmed();
    gpuPercent_ = fields[1].trimmed().toDouble();
    gpuTemp_ = fields[2].trimmed().toDouble();
    const double usedMb = fields[3].trimmed().toDouble();
    const double totalMb = fields[4].trimmed().toDouble();
    gpuMemoryPercent_ = totalMb > 0 ? 100.0 * usedMb / totalMb : 0.0;
    gpuMemoryUsed_ = formatBytes(usedMb * 1024.0 * 1024.0);
    gpuMemoryTotal_ = formatBytes(totalMb * 1024.0 * 1024.0);
    gpuPowerWatts_ = fields[5].trimmed().toDouble();
    gpuPowerLimit_ = fields[6].trimmed().toDouble();
    gpuFanPercent_ = fields[7].trimmed().toDouble();
    appendHistory(gpuHistory_, gpuPercent_);
    emit updated();
}

QString SystemMonitorService::formatBytes(double bytes) {
    if (bytes >= 1024.0 * 1024.0 * 1024.0)
        return QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 1) + QStringLiteral(" GB");
    if (bytes >= 1024.0 * 1024.0)
        return QString::number(bytes / (1024.0 * 1024.0), 'f', 0) + QStringLiteral(" MB");
    return QString::number(bytes / 1024.0, 'f', 0) + QStringLiteral(" KB");
}

QString SystemMonitorService::formatRate(double bytesPerSecond) {
    if (bytesPerSecond >= 1000.0 * 1000.0 * 1000.0)
        return QString::number(bytesPerSecond / 1000000000.0, 'f', 1) + QStringLiteral(" GB/s");
    if (bytesPerSecond >= 1000.0 * 1000.0)
        return QString::number(bytesPerSecond / 1000000.0, 'f', 1) + QStringLiteral(" MB/s");
    if (bytesPerSecond >= 1000.0)
        return QString::number(bytesPerSecond / 1000.0, 'f', 0) + QStringLiteral(" KB/s");
    return QString::number(bytesPerSecond, 'f', 0) + QStringLiteral(" B/s");
}

void SystemMonitorService::appendHistory(QVariantList &history, double value) {
    history.append(value);
    while (history.size() > 60)
        history.removeFirst();
}

} // namespace ciderdeck
