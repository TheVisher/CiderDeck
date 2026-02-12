#include "DeckConfig.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUuid>

namespace ciderdeck {

// --- PageData ---

QJsonObject PageData::toJson() const {
    QJsonArray tilesArray;
    for (const auto &tile : tiles) {
        tilesArray.append(tile.toJson());
    }
    return {
        {"id", id},
        {"name", name},
        {"tiles", tilesArray},
    };
}

PageData PageData::fromJson(const QJsonObject &obj) {
    PageData page;
    page.id = obj["id"].toString();
    page.name = obj["name"].toString();
    const auto tilesArray = obj["tiles"].toArray();
    for (const auto &val : tilesArray) {
        page.tiles.append(TileData::fromJson(val.toObject()));
    }
    return page;
}

// --- DeckConfig ---

DeckConfig::DeckConfig(QObject *parent)
    : QObject(parent) {
    load();
}

QString DeckConfig::configPath() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                        + QStringLiteral("/ciderdeck");
    QDir().mkpath(dir);
    return dir + QStringLiteral("/config.json");
}

void DeckConfig::load() {
    QFile file(configPath());
    if (!file.open(QIODevice::ReadOnly)) {
        ensureDefaultPage();
        emit configLoaded();
        return;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) {
        ensureDefaultPage();
        emit configLoaded();
        return;
    }

    const auto root = doc.object();
    const auto global = root["global"].toObject();

    gridColumns_ = global["gridColumns"].toInt(32);
    gridRows_ = global["gridRows"].toInt(8);
    gridGap_ = global["gridGap"].toInt(4);
    padding_ = global["padding"].toInt(8);
    cardRadius_ = global["cardRadius"].toInt(14);
    theme_ = global["theme"].toString(QStringLiteral("dark"));
    followSystemTheme_ = global["followSystemTheme"].toBool(false);
    globalBlur_ = global["globalBlur"].toBool(true);
    globalBlurLevel_ = global["globalBlurLevel"].toDouble(0.7);
    globalOpacity_ = global["globalOpacity"].toDouble(0.85);
    iconColorMode_ = global["iconColorMode"].toString(QStringLiteral("original"));
    showLabels_ = global["showLabels"].toBool(true);
    toastMonitor_ = global["toastMonitor"].toString();
    targetDisplay_ = global["targetDisplay"].toString();

    pages_.clear();
    const auto pagesArray = root["pages"].toArray();
    for (const auto &val : pagesArray) {
        pages_.append(PageData::fromJson(val.toObject()));
    }

    ensureDefaultPage();

    emit gridChanged();
    emit appearanceChanged();
    emit pagesChanged();
    emit tilesChanged();
    emit configLoaded();
}

void DeckConfig::save() {
    QJsonObject global;
    global["gridColumns"] = gridColumns_;
    global["gridRows"] = gridRows_;
    global["gridGap"] = gridGap_;
    global["padding"] = padding_;
    global["cardRadius"] = cardRadius_;
    global["theme"] = theme_;
    global["followSystemTheme"] = followSystemTheme_;
    global["globalBlur"] = globalBlur_;
    global["globalBlurLevel"] = globalBlurLevel_;
    global["globalOpacity"] = globalOpacity_;
    global["iconColorMode"] = iconColorMode_;
    global["showLabels"] = showLabels_;
    global["toastMonitor"] = toastMonitor_;
    global["targetDisplay"] = targetDisplay_;

    QJsonArray pagesArray;
    for (const auto &page : pages_) {
        pagesArray.append(page.toJson());
    }

    QJsonObject root;
    root["version"] = 2;
    root["global"] = global;
    root["pages"] = pagesArray;

    QFile file(configPath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}

void DeckConfig::exportConfig(const QString &path) {
    QFile src(configPath());
    if (src.exists()) {
        QFile::remove(path);
        src.copy(path);
    }
}

bool DeckConfig::importConfig(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject() || !doc.object().contains("version")) {
        return false;
    }

    QFile dest(configPath());
    if (dest.open(QIODevice::WriteOnly)) {
        dest.write(QJsonDocument(doc.object()).toJson(QJsonDocument::Indented));
    }

    load();
    return true;
}

void DeckConfig::addPage(const QString &name) {
    PageData page;
    page.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    page.name = name.isEmpty() ? QStringLiteral("Page %1").arg(pages_.size() + 1) : name;
    pages_.append(page);
    emit pagesChanged();
    save();
}

void DeckConfig::removePage(int index) {
    if (index < 0 || index >= pages_.size() || pages_.size() <= 1) {
        return;
    }
    pages_.removeAt(index);
    if (currentPage_ >= pages_.size()) {
        currentPage_ = pages_.size() - 1;
        emit currentPageChanged();
    }
    emit pagesChanged();
    emit tilesChanged();
    save();
}

QVariantList DeckConfig::tilesForPage(int page) const {
    if (page < 0 || page >= pages_.size()) {
        return {};
    }
    QVariantList list;
    for (const auto &tile : pages_[page].tiles) {
        list.append(tile.toVariantMap());
    }
    return list;
}

void DeckConfig::addTile(int page, const QVariantMap &tileMap) {
    if (page < 0 || page >= pages_.size()) {
        return;
    }

    TileData tile;
    tile.id = tileMap.value("id", QUuid::createUuid().toString(QUuid::WithoutBraces)).toString();
    tile.type = tileTypeFromString(tileMap.value("type", "app_launcher").toString());
    tile.col = tileMap.value("col", 0).toInt();
    tile.row = tileMap.value("row", 0).toInt();
    tile.colSpan = tileMap.value("colSpan", 4).toInt();
    tile.rowSpan = tileMap.value("rowSpan", 4).toInt();
    tile.label = tileMap.value("label").toString();
    tile.showLabel = tileMap.value("showLabel", true).toBool();
    tile.opacity = tileMap.value("opacity", -1.0).toDouble();
    tile.blurLevel = tileMap.value("blurLevel", -1.0).toDouble();
    tile.settings = tileMap.value("settings").toMap();

    pages_[page].tiles.append(tile);
    emit tilesChanged();
    save();
}

void DeckConfig::removeTile(const QString &tileId) {
    for (auto &page : pages_) {
        for (int i = 0; i < page.tiles.size(); ++i) {
            if (page.tiles[i].id == tileId) {
                page.tiles.removeAt(i);
                emit tilesChanged();
                save();
                return;
            }
        }
    }
}

void DeckConfig::updateTile(const QString &tileId, const QVariantMap &changes) {
    for (auto &page : pages_) {
        for (auto &tile : page.tiles) {
            if (tile.id != tileId) continue;

            if (changes.contains("label")) tile.label = changes["label"].toString();
            if (changes.contains("showLabel")) tile.showLabel = changes["showLabel"].toBool();
            if (changes.contains("opacity")) tile.opacity = changes["opacity"].toDouble();
            if (changes.contains("blurLevel")) tile.blurLevel = changes["blurLevel"].toDouble();
            if (changes.contains("settings")) {
                const auto newSettings = changes["settings"].toMap();
                for (auto it = newSettings.begin(); it != newSettings.end(); ++it) {
                    tile.settings[it.key()] = it.value();
                }
            }

            emit tilesChanged();
            save();
            return;
        }
    }
}

void DeckConfig::moveTile(const QString &tileId, int col, int row) {
    for (auto &page : pages_) {
        for (auto &tile : page.tiles) {
            if (tile.id == tileId) {
                tile.col = col;
                tile.row = row;
                emit tilesChanged();
                save();
                return;
            }
        }
    }
}

void DeckConfig::resizeTile(const QString &tileId, int colSpan, int rowSpan) {
    for (auto &page : pages_) {
        for (auto &tile : page.tiles) {
            if (tile.id == tileId) {
                tile.colSpan = qMax(1, colSpan);
                tile.rowSpan = qMax(1, rowSpan);
                emit tilesChanged();
                save();
                return;
            }
        }
    }
}

void DeckConfig::ensureDefaultPage() {
    if (pages_.isEmpty()) {
        PageData page;
        page.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        page.name = QStringLiteral("Page 1");
        pages_.append(page);
    }
}

int DeckConfig::findTilePage(const QString &tileId) const {
    for (int i = 0; i < pages_.size(); ++i) {
        for (const auto &tile : pages_[i].tiles) {
            if (tile.id == tileId) return i;
        }
    }
    return -1;
}

// Property setters
void DeckConfig::setGridColumns(int v) { if (gridColumns_ != v) { gridColumns_ = v; emit gridChanged(); save(); } }
void DeckConfig::setGridRows(int v) { if (gridRows_ != v) { gridRows_ = v; emit gridChanged(); save(); } }
void DeckConfig::setGridGap(int v) { if (gridGap_ != v) { gridGap_ = v; emit gridChanged(); save(); } }
void DeckConfig::setPadding(int v) { if (padding_ != v) { padding_ = v; emit gridChanged(); save(); } }
void DeckConfig::setCardRadius(int v) { if (cardRadius_ != v) { cardRadius_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setTheme(const QString &v) { if (theme_ != v) { theme_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setFollowSystemTheme(bool v) { if (followSystemTheme_ != v) { followSystemTheme_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setGlobalBlur(bool v) { if (globalBlur_ != v) { globalBlur_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setGlobalBlurLevel(qreal v) { if (!qFuzzyCompare(globalBlurLevel_, v)) { globalBlurLevel_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setGlobalOpacity(qreal v) { if (!qFuzzyCompare(globalOpacity_, v)) { globalOpacity_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setIconColorMode(const QString &v) { if (iconColorMode_ != v) { iconColorMode_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setShowLabels(bool v) { if (showLabels_ != v) { showLabels_ = v; emit appearanceChanged(); save(); } }
void DeckConfig::setToastMonitor(const QString &v) { if (toastMonitor_ != v) { toastMonitor_ = v; emit toastMonitorChanged(); save(); } }
void DeckConfig::setTargetDisplay(const QString &v) { if (targetDisplay_ != v) { targetDisplay_ = v; emit targetDisplayChanged(); save(); } }
void DeckConfig::setCurrentPage(int v) { if (currentPage_ != v && v >= 0 && v < pages_.size()) { currentPage_ = v; emit currentPageChanged(); } }

} // namespace ciderdeck
