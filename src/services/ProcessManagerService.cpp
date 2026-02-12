#include "ProcessManagerService.h"

#include <QDir>
#include <QFile>
#include <QTextStream>
#include <signal.h>
#include <algorithm>

namespace ciderdeck {

ProcessManagerService::ProcessManagerService(QObject *parent)
    : QAbstractListModel(parent)
    , timer_(new QTimer(this)) {
    timer_->setInterval(3000);
    connect(timer_, &QTimer::timeout, this, &ProcessManagerService::poll);
    timer_->start();
    poll();
}

int ProcessManagerService::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return processes_.size();
}

QVariant ProcessManagerService::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= processes_.size())
        return {};

    const auto &proc = processes_[index.row()];
    switch (role) {
    case PidRole:        return proc.pid;
    case NameRole:       return proc.name;
    case CpuPercentRole: return proc.cpuPercent;
    case MemoryRole:     return QString::number(proc.memKb / 1024.0, 'f', 1) + " MB";
    }
    return {};
}

QHash<int, QByteArray> ProcessManagerService::roleNames() const {
    return {
        {PidRole,        "pid"},
        {NameRole,       "name"},
        {CpuPercentRole, "cpuPercent"},
        {MemoryRole,     "memory"},
    };
}

void ProcessManagerService::killProcess(int pid) {
    ::kill(pid, SIGTERM);
    poll();
}

void ProcessManagerService::refresh() {
    poll();
}

void ProcessManagerService::poll() {
    QDir procDir("/proc");
    auto entries = procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    QList<ProcessInfo> newList;

    for (const auto &entry : entries) {
        bool ok = false;
        int pid = entry.toInt(&ok);
        if (!ok) continue;

        // Read comm for process name
        QFile commFile("/proc/" + entry + "/comm");
        if (!commFile.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        QString name = commFile.readAll().trimmed();
        commFile.close();

        // Read status for memory
        long long memKb = 0;
        QFile statusFile("/proc/" + entry + "/status");
        if (statusFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream stream(&statusFile);
            while (!stream.atEnd()) {
                QString line = stream.readLine();
                if (line.startsWith("VmRSS:")) {
                    memKb = line.split(' ', Qt::SkipEmptyParts).value(1).toLongLong();
                    break;
                }
            }
        }

        // Skip kernel threads (no memory)
        if (memKb == 0) continue;

        ProcessInfo info;
        info.pid = pid;
        info.name = name;
        info.memKb = memKb;
        newList.append(info);
    }

    // Sort by memory usage descending
    std::sort(newList.begin(), newList.end(), [](const ProcessInfo &a, const ProcessInfo &b) {
        return a.memKb > b.memKb;
    });

    // Limit to top 100
    if (newList.size() > 100) newList.resize(100);

    beginResetModel();
    processes_ = newList;
    endResetModel();
    emit processListChanged();
}

} // namespace ciderdeck
