#pragma once

#include <QObject>
#include <QAbstractListModel>
#include <QTimer>

namespace ciderdeck {

struct ProcessInfo {
    int pid = 0;
    QString name;
    double cpuPercent = 0.0;
    long long memKb = 0;
};

class ProcessManagerService : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int processCount READ processCount NOTIFY processListChanged)

public:
    enum Roles {
        PidRole = Qt::UserRole + 1,
        NameRole,
        CpuPercentRole,
        MemoryRole,
    };

    explicit ProcessManagerService(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int processCount() const { return processes_.size(); }

    Q_INVOKABLE void killProcess(int pid);
    Q_INVOKABLE void refresh();

signals:
    void processListChanged();

private:
    void poll();

    QTimer *timer_ = nullptr;
    QList<ProcessInfo> processes_;
};

} // namespace ciderdeck
