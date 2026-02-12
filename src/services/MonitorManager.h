#pragma once

#include <QObject>
#include <QVariantList>
#include <QList>
#include <QScreen>

#include "models/MonitorInfo.h"

namespace ciderdeck {

class MonitorManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList monitors READ monitorsAsVariant NOTIFY monitorsChanged)

public:
    explicit MonitorManager(QObject *parent = nullptr);

    QVariantList monitorsAsVariant() const;
    QList<MonitorInfo> monitors() const;

    Q_INVOKABLE void refresh();
    QScreen *findByResolution(int width, int height) const;
    QScreen *findByName(const QString &name) const;

signals:
    void monitorsChanged();

private:
    QList<MonitorInfo> monitors_;
};

} // namespace ciderdeck
