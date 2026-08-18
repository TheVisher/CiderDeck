#include "ClipboardService.h"

#include <QApplication>
#include <QClipboard>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QMimeData>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTimer>
#include <QUuid>

namespace ciderdeck {

ClipboardService::ClipboardService(QObject *parent)
    : QAbstractListModel(parent)
{
    databasePath_ = qEnvironmentVariable("KLIPPER_DATABASE");
    if (databasePath_.isEmpty()) {
        databasePath_ = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                        + QStringLiteral("/klipper/history3.sqlite");
    }
    dataRoot_ = QFileInfo(databasePath_).absolutePath() + QStringLiteral("/data");

    const bool signalConnected = QDBusConnection::sessionBus().connect(
        QStringLiteral("org.kde.klipper"),
        QStringLiteral("/klipper"),
        QStringLiteral("org.kde.klipper.klipper"),
        QStringLiteral("clipboardHistoryUpdated"),
        this,
        SLOT(scheduleRefresh()));
    if (!signalConnected)
        qWarning() << "[ClipboardService] Could not subscribe to Klipper history updates";

    // The clipboard signal is only a refresh hint. Klipper's database remains
    // the sole source of history and persistence.
    connect(QApplication::clipboard(), &QClipboard::dataChanged,
            this, &ClipboardService::scheduleRefresh);

    QTimer::singleShot(0, this, &ClipboardService::refresh);
}

int ClipboardService::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return history_.size();
}

QVariant ClipboardService::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= history_.size())
        return {};

    const auto &entry = history_[index.row()];
    switch (role) {
    case TextRole:      return entry.text;
    case TimestampRole: return entry.timestamp;
    case TimestampEpochRole: return entry.timestampEpoch;
    case IsImageRole:   return entry.isImage;
    case EntryIdRole:   return entry.uuid;
    case ImageSourceRole: return entry.imageSource;
    }
    return {};
}

QHash<int, QByteArray> ClipboardService::roleNames() const {
    return {
        {TextRole,      "text"},
        {TimestampRole, "timestamp"},
        {TimestampEpochRole, "timestampEpoch"},
        {IsImageRole,   "isImage"},
        {EntryIdRole,   "entryId"},
        {ImageSourceRole, "imageSource"},
    };
}

void ClipboardService::scheduleRefresh()
{
    if (refreshPending_)
        return;
    refreshPending_ = true;
    QTimer::singleShot(75, this, [this]() {
        refreshPending_ = false;
        refresh();
    });
}

void ClipboardService::refresh()
{
    if (!QFileInfo::exists(databasePath_)) {
        if (!history_.isEmpty()) {
            beginResetModel();
            history_.clear();
            endResetModel();
            emit historyChanged();
        }
        return;
    }

    QList<Entry> updated;
    bool loaded = false;
    const QString connectionName = QStringLiteral("ciderdeck-klipper-read-%1")
                                       .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    {
        QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        database.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        database.setDatabaseName(databasePath_);
        if (!database.open()) {
            qWarning() << "[ClipboardService] Could not read Klipper history:"
                       << database.lastError().text();
        } else {
            QSqlQuery query(database);
            query.prepare(QStringLiteral(
                "SELECT uuid, added_time, last_used_time, mimetypes, text "
                "FROM main ORDER BY last_used_time DESC, added_time DESC LIMIT ?"));
            query.addBindValue(maxEntries_);

            if (!query.exec()) {
                qWarning() << "[ClipboardService] Klipper history query failed:"
                           << query.lastError().text();
            } else {
                loaded = true;
                QSqlQuery imageQuery(database);
                imageQuery.prepare(QStringLiteral(
                    "SELECT data_uuid FROM aux WHERE uuid = ? AND mimetype = 'image/png'"));

                while (query.next()) {
                    Entry entry;
                    entry.uuid = query.value(0).toString();
                    const qint64 addedTime = query.value(1).toLongLong();
                    const qint64 lastUsedTime = query.value(2).toLongLong();
                    const qint64 displayTime = lastUsedTime > 0 ? lastUsedTime : addedTime;
                    entry.timestampEpoch = displayTime;
                    entry.timestamp = QDateTime::fromSecsSinceEpoch(displayTime)
                                          .toString(QStringLiteral("hh:mm:ss"));
                    const QString mimeTypes = query.value(3).toString();
                    entry.text = query.value(4).toString();
                    entry.isImage = mimeTypes.split(',').contains(QStringLiteral("image/png"));

                    if (entry.isImage) {
                        imageQuery.bindValue(0, entry.uuid);
                        if (imageQuery.exec() && imageQuery.next()) {
                            const QString imagePath = dataRoot_ + QLatin1Char('/') + entry.uuid
                                                      + QLatin1Char('/') + imageQuery.value(0).toString();
                            if (QFileInfo::exists(imagePath))
                                entry.imageSource = QUrl::fromLocalFile(imagePath);
                        }
                        imageQuery.finish();
                        if (entry.text.isEmpty())
                            entry.text = QStringLiteral("Image");
                    }
                    updated.append(std::move(entry));
                }
            }
            database.close();
        }
    }
    QSqlDatabase::removeDatabase(connectionName);

    // Keep the last successfully loaded history on a transient SQLite error.
    // Klipper may briefly hold the database while it records a clipboard change.
    if (!loaded)
        return;

    beginResetModel();
    history_ = std::move(updated);
    endResetModel();
    emit historyChanged();
}

void ClipboardService::copyToClipboard(int index)
{
    if (index < 0 || index >= history_.size())
        return;

    const Entry entry = history_.at(index);
    auto *mimeData = new QMimeData();
    const QString connectionName = QStringLiteral("ciderdeck-klipper-item-%1")
                                       .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    {
        QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        database.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        database.setDatabaseName(databasePath_);
        if (database.open()) {
            QSqlQuery query(database);
            query.prepare(QStringLiteral("SELECT mimetype, data_uuid FROM aux WHERE uuid = ?"));
            query.addBindValue(entry.uuid);
            if (query.exec()) {
                while (query.next()) {
                    const QString mimeType = query.value(0).toString();
                    const QString dataPath = dataRoot_ + QLatin1Char('/') + entry.uuid
                                             + QLatin1Char('/') + query.value(1).toString();
                    QFile dataFile(dataPath);
                    if (dataFile.open(QIODevice::ReadOnly))
                        mimeData->setData(mimeType, dataFile.readAll());
                }
            }
            database.close();
        }
    }
    QSqlDatabase::removeDatabase(connectionName);

    if (mimeData->formats().isEmpty() && !entry.text.isEmpty())
        mimeData->setText(entry.text);

    if (mimeData->formats().isEmpty()) {
        delete mimeData;
        qWarning() << "[ClipboardService] Klipper item data is unavailable";
        return;
    }

    QApplication::clipboard()->setMimeData(mimeData);
}

void ClipboardService::clear()
{
    QDBusInterface klipper(
        QStringLiteral("org.kde.klipper"),
        QStringLiteral("/klipper"),
        QStringLiteral("org.kde.klipper.klipper"),
        QDBusConnection::sessionBus());
    if (!klipper.isValid()) {
        qWarning() << "[ClipboardService] Klipper D-Bus interface is unavailable";
        return;
    }

    const QDBusMessage result = klipper.call(QStringLiteral("clearClipboardHistory"));
    if (result.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "[ClipboardService] Could not clear Klipper history:"
                   << result.errorMessage();
        return;
    }
    scheduleRefresh();
}

void ClipboardService::setMaxEntries(int max)
{
    const int bounded = qBound(1, max, 100);
    if (maxEntries_ == bounded)
        return;
    maxEntries_ = bounded;
    refresh();
}

} // namespace ciderdeck
