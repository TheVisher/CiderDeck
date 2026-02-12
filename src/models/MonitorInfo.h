#pragma once

#include <QRect>
#include <QString>
#include <QVariantMap>

namespace ciderdeck {

struct MonitorInfo {
    QString id;
    QString name;
    QRect geometry;
    QRect availableGeometry;
    bool isPrimary = false;

    QVariantMap toVariantMap() const {
        return {
            {"id", id},
            {"name", name},
            {"geometry", geometry},
            {"availableGeometry", availableGeometry},
            {"isPrimary", isPrimary},
        };
    }
};

} // namespace ciderdeck
