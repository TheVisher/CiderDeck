#include "TileGridModel.h"
#include "models/DeckConfig.h"

namespace ciderdeck {

TileGridModel::TileGridModel(DeckConfig *config, QObject *parent)
    : QAbstractListModel(parent)
    , config_(config) {
    connect(config_, &DeckConfig::tilesChanged, this, &TileGridModel::reload);
    connect(config_, &DeckConfig::configLoaded, this, &TileGridModel::reload);
    reload();
}

int TileGridModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return tiles_.size();
}

QVariant TileGridModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= tiles_.size()) {
        return {};
    }

    const auto tile = tiles_[index.row()].toMap();

    switch (role) {
    case IdRole:        return tile["id"];
    case TypeRole:      return tile["type"];
    case ColRole:       return tile["col"];
    case RowRole:       return tile["row"];
    case ColSpanRole:   return tile["colSpan"];
    case RowSpanRole:   return tile["rowSpan"];
    case LabelRole:     return tile["label"];
    case ShowLabelRole: return tile["showLabel"];
    case OpacityRole:   return tile["opacity"];
    case BlurLevelRole: return tile["blurLevel"];
    case SettingsRole:  return tile["settings"];
    }

    return {};
}

QHash<int, QByteArray> TileGridModel::roleNames() const {
    return {
        {IdRole,        "tileId"},
        {TypeRole,      "tileType"},
        {ColRole,       "col"},
        {RowRole,       "row"},
        {ColSpanRole,   "colSpan"},
        {RowSpanRole,   "rowSpan"},
        {LabelRole,     "label"},
        {ShowLabelRole, "showLabel"},
        {OpacityRole,   "tileOpacity"},
        {BlurLevelRole, "tileBlurLevel"},
        {SettingsRole,  "tileSettings"},
    };
}

void TileGridModel::setCurrentPage(int page) {
    if (currentPage_ != page) {
        currentPage_ = page;
        reload();
        emit currentPageChanged();
    }
}

void TileGridModel::reload() {
    beginResetModel();
    tiles_ = config_->tilesForPage(currentPage_);
    endResetModel();
}

bool TileGridModel::checkCollision(int col, int row, int colSpan, int rowSpan,
                                    const QString &excludeId) const {
    // Check grid bounds
    if (col < 0 || row < 0 ||
        col + colSpan > config_->gridColumns() ||
        row + rowSpan > config_->gridRows()) {
        return true;
    }

    for (const auto &v : tiles_) {
        const auto tile = v.toMap();
        if (tile["id"].toString() == excludeId) continue;

        const int tc = tile["col"].toInt();
        const int tr = tile["row"].toInt();
        const int tcs = tile["colSpan"].toInt();
        const int trs = tile["rowSpan"].toInt();

        // AABB overlap test
        bool overlaps = !(col + colSpan <= tc ||
                          tc + tcs <= col ||
                          row + rowSpan <= tr ||
                          tr + trs <= row);
        if (overlaps) return true;
    }

    return false;
}

QVariantMap TileGridModel::findFreePosition(int colSpan, int rowSpan) const {
    for (int r = 0; r <= config_->gridRows() - rowSpan; ++r) {
        for (int c = 0; c <= config_->gridColumns() - colSpan; ++c) {
            if (!checkCollision(c, r, colSpan, rowSpan)) {
                return {{"col", c}, {"row", r}};
            }
        }
    }
    return {};
}

QVariantMap TileGridModel::getTileById(const QString &tileId) const {
    for (const auto &v : tiles_) {
        const auto tile = v.toMap();
        if (tile["id"].toString() == tileId) {
            return tile;
        }
    }
    return {};
}

} // namespace ciderdeck
