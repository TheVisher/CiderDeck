#include "ToastModel.h"

namespace ciderdeck {

ToastModel::ToastModel(QObject *parent)
    : QAbstractListModel(parent) {}

int ToastModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return toasts_.size();
}

QVariant ToastModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= toasts_.size()) {
        return {};
    }

    const auto &toast = toasts_[index.row()];
    switch (role) {
    case IdRole:          return toast.id;
    case MessageRole:     return toast.message;
    case ActionLabelRole: return toast.actionLabel;
    case ActionIdRole:    return toast.actionId;
    case DurationRole:    return toast.duration;
    }
    return {};
}

QHash<int, QByteArray> ToastModel::roleNames() const {
    return {
        {IdRole,          "toastId"},
        {MessageRole,     "message"},
        {ActionLabelRole, "actionLabel"},
        {ActionIdRole,    "actionId"},
        {DurationRole,    "duration"},
    };
}

void ToastModel::show(const QString &message, int durationMs) {
    showWithAction(message, QString(), QString(), durationMs);
}

void ToastModel::showWithAction(const QString &message, const QString &actionLabel,
                                 const QString &actionId, int durationMs) {
    ToastData toast;
    toast.id = QString::number(nextId_++);
    toast.message = message;
    toast.actionLabel = actionLabel;
    toast.actionId = actionId;
    toast.duration = durationMs;

    beginInsertRows(QModelIndex(), toasts_.size(), toasts_.size());
    toasts_.append(toast);
    endInsertRows();

    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(durationMs);
    connect(timer, &QTimer::timeout, this, [this, id = toast.id]() {
        removeToast(id);
    });
    timer->start();
    timers_[toast.id] = timer;
}

void ToastModel::dismiss(const QString &toastId) {
    removeToast(toastId);
}

void ToastModel::triggerAction(const QString &toastId) {
    for (const auto &toast : toasts_) {
        if (toast.id == toastId) {
            emit actionTriggered(toast.actionId);
            removeToast(toastId);
            return;
        }
    }
}

void ToastModel::removeToast(const QString &id) {
    for (int i = 0; i < toasts_.size(); ++i) {
        if (toasts_[i].id == id) {
            beginRemoveRows(QModelIndex(), i, i);
            toasts_.removeAt(i);
            endRemoveRows();

            if (timers_.contains(id)) {
                timers_[id]->deleteLater();
                timers_.remove(id);
            }
            return;
        }
    }
}

} // namespace ciderdeck
