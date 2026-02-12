#include "EditModeController.h"
#include "models/DeckConfig.h"
#include "viewmodels/TileGridModel.h"
#include "models/TileType.h"

#include <QUuid>

namespace ciderdeck {

EditModeController::EditModeController(DeckConfig *config, TileGridModel *gridModel, QObject *parent)
    : QObject(parent)
    , config_(config)
    , gridModel_(gridModel) {}

void EditModeController::enterEditMode() {
    if (!editing_) {
        editing_ = true;
        emit editingChanged();
    }
}

void EditModeController::exitEditMode() {
    if (editing_) {
        cancelDrag();
        editing_ = false;
        emit editingChanged();
    }
}

void EditModeController::toggleEditMode() {
    if (editing_) exitEditMode();
    else enterEditMode();
}

void EditModeController::beginDrag(const QString &tileId, int col, int row, int colSpan, int rowSpan) {
    dragTileId_ = tileId;
    ghostCol_ = col;
    ghostRow_ = row;
    ghostColSpan_ = colSpan;
    ghostRowSpan_ = rowSpan;
    ghostValid_ = true;
    dragging_ = true;
    emit dragStateChanged();
}

void EditModeController::updateDrag(qreal pixelX, qreal pixelY, qreal cellWidth, qreal cellHeight,
                                     int gridGap, int gridPadding) {
    if (!dragging_) return;

    int newCol = snapToGrid(pixelX, cellWidth, gridGap, gridPadding, config_->gridColumns() - ghostColSpan_);
    int newRow = snapToGrid(pixelY, cellHeight, gridGap, gridPadding, config_->gridRows() - ghostRowSpan_);

    ghostCol_ = newCol;
    ghostRow_ = newRow;
    ghostValid_ = !gridModel_->checkCollision(newCol, newRow, ghostColSpan_, ghostRowSpan_, dragTileId_);
    emit dragStateChanged();
}

void EditModeController::endDrag() {
    if (!dragging_ || dragTileId_.isEmpty()) return;

    if (ghostValid_) {
        config_->moveTile(dragTileId_, ghostCol_, ghostRow_);
    }

    dragging_ = false;
    dragTileId_.clear();
    emit dragStateChanged();
}

void EditModeController::cancelDrag() {
    if (dragging_) {
        dragging_ = false;
        dragTileId_.clear();
        emit dragStateChanged();
    }
    if (resizing_) {
        resizing_ = false;
        dragTileId_.clear();
        emit dragStateChanged();
    }
}

void EditModeController::beginResize(const QString &tileId, int col, int row, int colSpan, int rowSpan) {
    dragTileId_ = tileId;
    ghostCol_ = col;
    ghostRow_ = row;
    ghostColSpan_ = colSpan;
    ghostRowSpan_ = rowSpan;
    ghostValid_ = true;
    resizing_ = true;
    emit dragStateChanged();
}

void EditModeController::updateResize(qreal pixelX, qreal pixelY, qreal cellWidth, qreal cellHeight,
                                        int gridGap, int gridPadding) {
    if (!resizing_) return;

    // Calculate new span from the bottom-right corner position
    int endCol = snapToGrid(pixelX, cellWidth, gridGap, gridPadding, config_->gridColumns() - 1) + 1;
    int endRow = snapToGrid(pixelY, cellHeight, gridGap, gridPadding, config_->gridRows() - 1) + 1;

    int newColSpan = qMax(1, endCol - ghostCol_);
    int newRowSpan = qMax(1, endRow - ghostRow_);

    ghostColSpan_ = newColSpan;
    ghostRowSpan_ = newRowSpan;
    ghostValid_ = !gridModel_->checkCollision(ghostCol_, ghostRow_, newColSpan, newRowSpan, dragTileId_);
    emit dragStateChanged();
}

void EditModeController::endResize() {
    if (!resizing_ || dragTileId_.isEmpty()) return;

    if (ghostValid_) {
        config_->resizeTile(dragTileId_, ghostColSpan_, ghostRowSpan_);
    }

    resizing_ = false;
    dragTileId_.clear();
    emit dragStateChanged();
}

void EditModeController::deleteTile(const QString &tileId) {
    // Store undo data
    const auto tiles = config_->tilesForPage(config_->currentPage());
    for (const auto &v : tiles) {
        const auto tile = v.toMap();
        if (tile["id"].toString() == tileId) {
            undoTileData_ = tile;
            undoPage_ = config_->currentPage();
            break;
        }
    }

    config_->removeTile(tileId);
    emit tileDeleted(tileId);
}

void EditModeController::undoDelete() {
    if (undoTileData_.isEmpty() || undoPage_ < 0) return;

    config_->addTile(undoPage_, undoTileData_);
    undoTileData_.clear();
    undoPage_ = -1;
    emit tileDeleteUndone();
}

void EditModeController::addTile(const QString &typeStr) {
    TileType type = tileTypeFromString(typeStr);

    // Default sizes per tile type
    int colSpan = 4, rowSpan = 4;
    switch (type) {
    case TileType::ClockDate:
    case TileType::CommandButton:
        colSpan = 4; rowSpan = 4; break;
    case TileType::MediaPlayer:
        colSpan = 8; rowSpan = 4; break;
    case TileType::Volume:
        colSpan = 4; rowSpan = 6; break;
    case TileType::Weather:
        colSpan = 8; rowSpan = 2; break;
    case TileType::ProcessManager:
        colSpan = 8; rowSpan = 6; break;
    default:
        colSpan = 4; rowSpan = 4; break;
    }

    auto pos = gridModel_->findFreePosition(colSpan, rowSpan);
    if (pos.isEmpty()) {
        // Try smallest size
        colSpan = 2; rowSpan = 2;
        pos = gridModel_->findFreePosition(colSpan, rowSpan);
        if (pos.isEmpty()) return;
    }

    QVariantMap tileMap;
    tileMap["id"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    tileMap["type"] = typeStr;
    tileMap["col"] = pos["col"];
    tileMap["row"] = pos["row"];
    tileMap["colSpan"] = colSpan;
    tileMap["rowSpan"] = rowSpan;
    tileMap["label"] = typeStr;
    tileMap["showLabel"] = true;

    config_->addTile(config_->currentPage(), tileMap);
    emit tileAdded(tileMap["id"].toString());

    if (!editing_) enterEditMode();
}

int EditModeController::snapToGrid(qreal pixel, qreal cellSize, int gap, int padding, int maxCells) const {
    int cell = qRound((pixel - padding) / (cellSize + gap));
    return qBound(0, cell, maxCells);
}

} // namespace ciderdeck
