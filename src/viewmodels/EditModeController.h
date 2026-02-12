#pragma once

#include <QObject>
#include <QVariantMap>

namespace ciderdeck {

class DeckConfig;
class TileGridModel;

class EditModeController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool editing READ editing NOTIFY editingChanged)
    Q_PROPERTY(QString dragTileId READ dragTileId NOTIFY dragStateChanged)
    Q_PROPERTY(int ghostCol READ ghostCol NOTIFY dragStateChanged)
    Q_PROPERTY(int ghostRow READ ghostRow NOTIFY dragStateChanged)
    Q_PROPERTY(int ghostColSpan READ ghostColSpan NOTIFY dragStateChanged)
    Q_PROPERTY(int ghostRowSpan READ ghostRowSpan NOTIFY dragStateChanged)
    Q_PROPERTY(bool ghostValid READ ghostValid NOTIFY dragStateChanged)

public:
    explicit EditModeController(DeckConfig *config, TileGridModel *gridModel, QObject *parent = nullptr);

    bool editing() const { return editing_; }
    QString dragTileId() const { return dragTileId_; }
    int ghostCol() const { return ghostCol_; }
    int ghostRow() const { return ghostRow_; }
    int ghostColSpan() const { return ghostColSpan_; }
    int ghostRowSpan() const { return ghostRowSpan_; }
    bool ghostValid() const { return ghostValid_; }

    Q_INVOKABLE void enterEditMode();
    Q_INVOKABLE void exitEditMode();
    Q_INVOKABLE void toggleEditMode();

    // Drag operations
    Q_INVOKABLE void beginDrag(const QString &tileId, int col, int row, int colSpan, int rowSpan);
    Q_INVOKABLE void updateDrag(qreal pixelX, qreal pixelY, qreal cellWidth, qreal cellHeight,
                                 int gridGap, int gridPadding);
    Q_INVOKABLE void endDrag();
    Q_INVOKABLE void cancelDrag();

    // Resize operations
    Q_INVOKABLE void beginResize(const QString &tileId, int col, int row, int colSpan, int rowSpan);
    Q_INVOKABLE void updateResize(qreal pixelX, qreal pixelY, qreal cellWidth, qreal cellHeight,
                                    int gridGap, int gridPadding);
    Q_INVOKABLE void endResize();

    // Delete with undo support
    Q_INVOKABLE void deleteTile(const QString &tileId);
    Q_INVOKABLE void undoDelete();
    Q_INVOKABLE bool hasUndoData() const { return !undoTileData_.isEmpty(); }

    // Add tile
    Q_INVOKABLE void addTile(const QString &typeStr);

signals:
    void editingChanged();
    void dragStateChanged();
    void tileDeleted(const QString &tileId);
    void tileDeleteUndone();
    void tileAdded(const QString &tileId);

private:
    int snapToGrid(qreal pixel, qreal cellSize, int gap, int padding, int maxCells) const;

    DeckConfig *config_;
    TileGridModel *gridModel_;
    bool editing_ = false;
    bool dragging_ = false;
    bool resizing_ = false;

    // Drag state
    QString dragTileId_;
    int ghostCol_ = 0;
    int ghostRow_ = 0;
    int ghostColSpan_ = 1;
    int ghostRowSpan_ = 1;
    bool ghostValid_ = true;

    // Undo state
    QVariantMap undoTileData_;
    int undoPage_ = -1;
};

} // namespace ciderdeck
