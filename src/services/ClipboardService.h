#pragma once

#include <QObject>
#include <QAbstractListModel>

namespace ciderdeck {

class ClipboardService : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY historyChanged)

public:
    enum Roles {
        TextRole = Qt::UserRole + 1,
        TimestampRole,
        IsImageRole,
    };

    explicit ClipboardService(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return history_.size(); }

    Q_INVOKABLE void copyToClipboard(int index);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void setMaxEntries(int max);

signals:
    void historyChanged();

private slots:
    void onClipboardChanged();

private:
    struct Entry {
        QString text;
        QString timestamp;
        bool isImage = false;
    };

    QList<Entry> history_;
    int maxEntries_ = 20;
};

} // namespace ciderdeck
