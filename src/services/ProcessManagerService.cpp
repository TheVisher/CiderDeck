#include "ProcessManagerService.h"
#include "KWinDBusClient.h"

#include <QDir>
#include <QFile>
#include <QJsonObject>
#include <QTextStream>
#include <signal.h>
#include <algorithm>

namespace ciderdeck {

ProcessManagerService::ProcessManagerService(QObject *parent)
    : QAbstractListModel(parent)
    , timer_(new QTimer(this)) {
    timer_->setInterval(3000);
    connect(timer_, &QTimer::timeout, this, &ProcessManagerService::poll);
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
    case UnresponsiveRole: return proc.unresponsive;
    }
    return {};
}

QHash<int, QByteArray> ProcessManagerService::roleNames() const {
    return {
        {PidRole,        "pid"},
        {NameRole,       "name"},
        {CpuPercentRole, "cpuPercent"},
        {MemoryRole,     "memory"},
        {UnresponsiveRole, "unresponsive"},
    };
}

void ProcessManagerService::killProcess(int pid) {
    ::kill(pid, SIGTERM);
    poll();
}

void ProcessManagerService::refresh() {
    poll();
}

void ProcessManagerService::setConsumerActive(QObject *consumer, bool active) {
    if (!consumer)
        return;

    if (active) {
        if (activeConsumers_.contains(consumer))
            return;

        if (!trackedConsumers_.contains(consumer)) {
            trackedConsumers_.insert(consumer);
            connect(consumer, &QObject::destroyed,
                    this, &ProcessManagerService::consumerDestroyed);
        }

        const bool firstConsumer = activeConsumers_.isEmpty();
        activeConsumers_.insert(consumer);
        if (firstConsumer) {
            poll();
            timer_->start();
        }
        return;
    }

    if (!activeConsumers_.remove(consumer))
        return;
    if (activeConsumers_.isEmpty())
        timer_->stop();
}

void ProcessManagerService::consumerDestroyed(QObject *consumer) {
    trackedConsumers_.remove(consumer);
    if (activeConsumers_.remove(consumer) && activeConsumers_.isEmpty())
        timer_->stop();
}

void ProcessManagerService::setKWinClient(KWinDBusClient *client) {
    if (!client)
        return;
    connect(client, &KWinDBusClient::windowPayloadReceived,
            this, &ProcessManagerService::updateWindowStates);
}

void ProcessManagerService::updateWindowStates(const QJsonArray &windows) {
    QSet<int> updatedPids;
    for (const auto &value : windows) {
        const auto window = value.toObject();
        if (window.value(QStringLiteral("unresponsive")).toBool()) {
            const int pid = window.value(QStringLiteral("pid")).toInt();
            if (pid > 0)
                updatedPids.insert(pid);
        }
    }
    if (updatedPids == unresponsivePids_)
        return;
    unresponsivePids_ = std::move(updatedPids);
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
        char processState = '\0';
        QFile statusFile("/proc/" + entry + "/status");
        if (statusFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            for (;;) {
                const QByteArray line = statusFile.readLine();
                if (line.isEmpty())
                    break;
                if (line.startsWith("VmRSS:")) {
                    memKb = line.simplified().split(' ').value(1).toLongLong();
                } else if (line.startsWith("State:")) {
                    const auto fields = line.simplified().split(' ');
                    if (fields.size() > 1 && !fields[1].isEmpty())
                        processState = fields[1].at(0);
                }
            }
        }

        // Skip kernel threads (no memory)
        if (memKb == 0) continue;

        ProcessInfo info;
        info.pid = pid;
        info.name = name;
        info.memKb = memKb;
        info.unresponsive = unresponsivePids_.contains(pid)
                            || processState == 'D' || processState == 'Z';
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
