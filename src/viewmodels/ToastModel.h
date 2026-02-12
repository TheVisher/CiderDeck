#pragma once

#include <QAbstractListModel>
#include <QTimer>
#include <QVariantMap>

namespace ciderdeck {

struct ToastData {
    QString id;
    QString message;
    QString actionLabel;
    QString actionId;
    int duration = 4000;
};

class ToastModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        MessageRole,
        ActionLabelRole,
        ActionIdRole,
        DurationRole,
    };

    explicit ToastModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void show(const QString &message, int durationMs = 4000);
    Q_INVOKABLE void showWithAction(const QString &message, const QString &actionLabel,
                                     const QString &actionId, int durationMs = 5000);
    Q_INVOKABLE void dismiss(const QString &toastId);
    Q_INVOKABLE void triggerAction(const QString &toastId);

signals:
    void actionTriggered(const QString &actionId);

private:
    void removeToast(const QString &id);

    QList<ToastData> toasts_;
    QMap<QString, QTimer *> timers_;
    int nextId_ = 0;
};

} // namespace ciderdeck
