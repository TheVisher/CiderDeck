#include "MonitorManager.h"

#include <QGuiApplication>
#include <QScreen>

namespace ciderdeck {

MonitorManager::MonitorManager(QObject *parent)
    : QObject(parent) {
    refresh();

    connect(qGuiApp, &QGuiApplication::screenAdded, this, [this](QScreen *) {
        refresh();
    });
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, [this](QScreen *) {
        refresh();
    });
}

QVariantList MonitorManager::monitorsAsVariant() const {
    QVariantList list;
    list.reserve(monitors_.size());
    for (const auto &monitor : monitors_) {
        list.append(monitor.toVariantMap());
    }
    return list;
}

QList<MonitorInfo> MonitorManager::monitors() const {
    return monitors_;
}

void MonitorManager::refresh() {
    const auto screens = QGuiApplication::screens();

    QList<MonitorInfo> next;
    next.reserve(screens.size());

    for (int i = 0; i < screens.size(); ++i) {
        const auto *screen = screens.at(i);
        MonitorInfo monitor;
        monitor.id = screen->name();
        monitor.name = screen->name();
        monitor.geometry = screen->geometry();
        monitor.availableGeometry = screen->availableGeometry();
        monitor.isPrimary = (screen == QGuiApplication::primaryScreen() || i == 0);
        next.push_back(monitor);
    }

    monitors_ = next;
    emit monitorsChanged();
}

QScreen *MonitorManager::findByResolution(int width, int height) const {
    const auto screens = QGuiApplication::screens();
    for (auto *screen : screens) {
        if (screen->size().width() == width && screen->size().height() == height) {
            return screen;
        }
    }
    return nullptr;
}

QScreen *MonitorManager::findByName(const QString &name) const {
    const auto screens = QGuiApplication::screens();
    for (auto *screen : screens) {
        if (screen->name() == name) {
            return screen;
        }
    }
    return nullptr;
}

} // namespace ciderdeck
