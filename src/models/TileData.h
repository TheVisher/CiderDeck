#pragma once

#include <QString>
#include <QVariantMap>
#include <QJsonObject>
#include <QUuid>

#include "TileType.h"

namespace ciderdeck {

struct TileData {
    QString id;
    TileType type = TileType::AppLauncher;
    int col = 0;
    int row = 0;
    int colSpan = 4;
    int rowSpan = 4;
    QString label;
    bool showLabel = true;
    qreal opacity = -1.0;
    qreal blurLevel = -1.0;
    QVariantMap settings;

    static TileData createNew(TileType type) {
        TileData tile;
        tile.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        tile.type = type;
        return tile;
    }

    QVariantMap toVariantMap() const {
        return {
            {"id", id},
            {"type", tileTypeToString(type)},
            {"col", col},
            {"row", row},
            {"colSpan", colSpan},
            {"rowSpan", rowSpan},
            {"label", label},
            {"showLabel", showLabel},
            {"opacity", opacity},
            {"blurLevel", blurLevel},
            {"settings", settings},
        };
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["type"] = tileTypeToString(type);
        obj["col"] = col;
        obj["row"] = row;
        obj["colSpan"] = colSpan;
        obj["rowSpan"] = rowSpan;
        obj["label"] = label;
        obj["showLabel"] = showLabel;
        obj["opacity"] = opacity;
        obj["blurLevel"] = blurLevel;
        obj["settings"] = QJsonObject::fromVariantMap(settings);
        return obj;
    }

    static TileData fromJson(const QJsonObject &obj) {
        TileData tile;
        tile.id = obj["id"].toString();
        tile.type = tileTypeFromString(obj["type"].toString());
        tile.col = obj["col"].toInt();
        tile.row = obj["row"].toInt();
        tile.colSpan = obj["colSpan"].toInt(4);
        tile.rowSpan = obj["rowSpan"].toInt(4);
        tile.label = obj["label"].toString();
        tile.showLabel = obj["showLabel"].toBool(true);
        tile.opacity = obj["opacity"].toDouble(-1.0);
        tile.blurLevel = obj["blurLevel"].toDouble(-1.0);
        tile.settings = obj["settings"].toObject().toVariantMap();
        return tile;
    }
};

} // namespace ciderdeck
