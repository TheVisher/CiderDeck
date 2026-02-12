#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QList>

#include "TileData.h"

namespace ciderdeck {

struct PageData {
    QString id;
    QString name;
    QList<TileData> tiles;

    QJsonObject toJson() const;
    static PageData fromJson(const QJsonObject &obj);
};

class DeckConfig : public QObject {
    Q_OBJECT

    Q_PROPERTY(int gridColumns READ gridColumns WRITE setGridColumns NOTIFY gridChanged)
    Q_PROPERTY(int gridRows READ gridRows WRITE setGridRows NOTIFY gridChanged)
    Q_PROPERTY(int gridGap READ gridGap WRITE setGridGap NOTIFY gridChanged)
    Q_PROPERTY(int padding READ padding WRITE setPadding NOTIFY gridChanged)
    Q_PROPERTY(int cardRadius READ cardRadius WRITE setCardRadius NOTIFY appearanceChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY appearanceChanged)
    Q_PROPERTY(bool followSystemTheme READ followSystemTheme WRITE setFollowSystemTheme NOTIFY appearanceChanged)
    Q_PROPERTY(bool globalBlur READ globalBlur WRITE setGlobalBlur NOTIFY appearanceChanged)
    Q_PROPERTY(qreal globalBlurLevel READ globalBlurLevel WRITE setGlobalBlurLevel NOTIFY appearanceChanged)
    Q_PROPERTY(qreal globalOpacity READ globalOpacity WRITE setGlobalOpacity NOTIFY appearanceChanged)
    Q_PROPERTY(QString iconColorMode READ iconColorMode WRITE setIconColorMode NOTIFY appearanceChanged)
    Q_PROPERTY(bool showLabels READ showLabels WRITE setShowLabels NOTIFY appearanceChanged)
    Q_PROPERTY(QString toastMonitor READ toastMonitor WRITE setToastMonitor NOTIFY toastMonitorChanged)
    Q_PROPERTY(QString targetDisplay READ targetDisplay WRITE setTargetDisplay NOTIFY targetDisplayChanged)
    Q_PROPERTY(int currentPage READ currentPage WRITE setCurrentPage NOTIFY currentPageChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY pagesChanged)

public:
    explicit DeckConfig(QObject *parent = nullptr);

    // Grid
    int gridColumns() const { return gridColumns_; }
    int gridRows() const { return gridRows_; }
    int gridGap() const { return gridGap_; }
    int padding() const { return padding_; }
    void setGridColumns(int v);
    void setGridRows(int v);
    void setGridGap(int v);
    void setPadding(int v);

    // Appearance
    int cardRadius() const { return cardRadius_; }
    QString theme() const { return theme_; }
    bool followSystemTheme() const { return followSystemTheme_; }
    bool globalBlur() const { return globalBlur_; }
    qreal globalBlurLevel() const { return globalBlurLevel_; }
    qreal globalOpacity() const { return globalOpacity_; }
    QString iconColorMode() const { return iconColorMode_; }
    bool showLabels() const { return showLabels_; }
    void setCardRadius(int v);
    void setTheme(const QString &v);
    void setFollowSystemTheme(bool v);
    void setGlobalBlur(bool v);
    void setGlobalBlurLevel(qreal v);
    void setGlobalOpacity(qreal v);
    void setIconColorMode(const QString &v);
    void setShowLabels(bool v);

    // Display
    QString toastMonitor() const { return toastMonitor_; }
    QString targetDisplay() const { return targetDisplay_; }
    void setToastMonitor(const QString &v);
    void setTargetDisplay(const QString &v);

    // Pages
    int currentPage() const { return currentPage_; }
    int pageCount() const { return pages_.size(); }
    void setCurrentPage(int v);

    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    Q_INVOKABLE void exportConfig(const QString &path);
    Q_INVOKABLE bool importConfig(const QString &path);

    Q_INVOKABLE void addPage(const QString &name = QString());
    Q_INVOKABLE void removePage(int index);

    Q_INVOKABLE QVariantList tilesForPage(int page) const;
    Q_INVOKABLE void addTile(int page, const QVariantMap &tileMap);
    Q_INVOKABLE void removeTile(const QString &tileId);
    Q_INVOKABLE void updateTile(const QString &tileId, const QVariantMap &changes);
    Q_INVOKABLE void moveTile(const QString &tileId, int col, int row);
    Q_INVOKABLE void resizeTile(const QString &tileId, int colSpan, int rowSpan);

    const QList<PageData> &pages() const { return pages_; }
    QString configPath() const;

signals:
    void gridChanged();
    void appearanceChanged();
    void toastMonitorChanged();
    void targetDisplayChanged();
    void currentPageChanged();
    void pagesChanged();
    void tilesChanged();
    void configLoaded();

private:
    void ensureDefaultPage();
    int findTilePage(const QString &tileId) const;

    // Grid
    int gridColumns_ = 32;
    int gridRows_ = 8;
    int gridGap_ = 4;
    int padding_ = 8;

    // Appearance
    int cardRadius_ = 14;
    QString theme_ = QStringLiteral("dark");
    bool followSystemTheme_ = false;
    bool globalBlur_ = true;
    qreal globalBlurLevel_ = 0.7;
    qreal globalOpacity_ = 0.85;
    QString iconColorMode_ = QStringLiteral("original");
    bool showLabels_ = true;

    // Display
    QString toastMonitor_;
    QString targetDisplay_;

    // Pages
    int currentPage_ = 0;
    QList<PageData> pages_;
};

} // namespace ciderdeck
