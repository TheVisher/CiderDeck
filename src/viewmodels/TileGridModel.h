#pragma once

#include <QAbstractListModel>
#include <QVariantMap>

namespace ciderdeck {

class DeckConfig;

class TileGridModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int currentPage READ currentPage WRITE setCurrentPage NOTIFY currentPageChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TypeRole,
        ColRole,
        RowRole,
        ColSpanRole,
        RowSpanRole,
        LabelRole,
        ShowLabelRole,
        OpacityRole,
        BlurLevelRole,
        SettingsRole,
    };

    explicit TileGridModel(DeckConfig *config, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int currentPage() const { return currentPage_; }
    void setCurrentPage(int page);

    Q_INVOKABLE bool checkCollision(int col, int row, int colSpan, int rowSpan,
                                     const QString &excludeId = QString()) const;
    Q_INVOKABLE QVariantMap findFreePosition(int colSpan, int rowSpan) const;
    Q_INVOKABLE QVariantMap getTileById(const QString &tileId) const;

signals:
    void currentPageChanged();

public slots:
    void reload();

private:
    DeckConfig *config_;
    int currentPage_ = 0;
    QVariantList tiles_;
};

} // namespace ciderdeck
