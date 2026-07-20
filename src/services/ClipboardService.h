#pragma once

#include <QObject>
#include <QAbstractListModel>
#include <QUrl>

namespace ciderdeck {

class ClipboardService : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY historyChanged)

public:
    enum Roles {
        TextRole = Qt::UserRole + 1,
        TimestampRole,
        TimestampEpochRole,
        IsImageRole,
        EntryIdRole,
        ImageSourceRole,
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
    void scheduleRefresh();

private:
    void refresh();

    struct Entry {
        QString uuid;
        QString text;
        QString timestamp;
        qint64 timestampEpoch = 0;
        bool isImage = false;
        QUrl imageSource;
    };

    QString databasePath_;
    QString dataRoot_;
    QList<Entry> history_;
    int maxEntries_ = 20;
    bool refreshPending_ = false;
};

} // namespace ciderdeck
