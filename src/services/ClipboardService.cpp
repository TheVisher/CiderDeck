#include "ClipboardService.h"

#include <QApplication>
#include <QClipboard>
#include <QDateTime>
#include <QMimeData>

namespace ciderdeck {

ClipboardService::ClipboardService(QObject *parent)
    : QAbstractListModel(parent) {
    auto *clipboard = QApplication::clipboard();
    connect(clipboard, &QClipboard::dataChanged, this, &ClipboardService::onClipboardChanged);
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
    case IsImageRole:   return entry.isImage;
    }
    return {};
}

QHash<int, QByteArray> ClipboardService::roleNames() const {
    return {
        {TextRole,      "text"},
        {TimestampRole, "timestamp"},
        {IsImageRole,   "isImage"},
    };
}

void ClipboardService::onClipboardChanged() {
    auto *clipboard = QApplication::clipboard();
    auto *mime = clipboard->mimeData();
    if (!mime) return;

    Entry entry;
    entry.timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");

    if (mime->hasText() && !mime->text().trimmed().isEmpty()) {
        entry.text = mime->text().left(500); // Limit text length
    } else if (mime->hasImage()) {
        entry.text = "[Image]";
        entry.isImage = true;
    } else {
        return;
    }

    // Don't add duplicates at the top
    if (!history_.isEmpty() && history_.first().text == entry.text) return;

    beginInsertRows(QModelIndex(), 0, 0);
    history_.prepend(entry);
    endInsertRows();

    // Trim to max
    while (history_.size() > maxEntries_) {
        beginRemoveRows(QModelIndex(), history_.size() - 1, history_.size() - 1);
        history_.removeLast();
        endRemoveRows();
    }

    emit historyChanged();
}

void ClipboardService::copyToClipboard(int index) {
    if (index < 0 || index >= history_.size()) return;
    QApplication::clipboard()->setText(history_[index].text);
}

void ClipboardService::clear() {
    beginResetModel();
    history_.clear();
    endResetModel();
    emit historyChanged();
}

void ClipboardService::setMaxEntries(int max) {
    maxEntries_ = qMax(1, max);
    while (history_.size() > maxEntries_) {
        beginRemoveRows(QModelIndex(), history_.size() - 1, history_.size() - 1);
        history_.removeLast();
        endRemoveRows();
    }
}

} // namespace ciderdeck
