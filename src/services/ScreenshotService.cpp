#include "ScreenshotService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QStringList>

namespace ciderdeck {

ScreenshotService::ScreenshotService(QObject *parent)
    : QObject(parent) {}

bool ScreenshotService::triggerShortcut() {
    constexpr int shortcutKey = static_cast<int>(Qt::MetaModifier)
                              | static_cast<int>(Qt::ShiftModifier)
                              | static_cast<int>(Qt::Key_S);

    QDBusInterface globalAccel(
        QStringLiteral("org.kde.kglobalaccel"),
        QStringLiteral("/kglobalaccel"),
        QStringLiteral("org.kde.KGlobalAccel"),
        QDBusConnection::sessionBus());
    if (!globalAccel.isValid()) {
        emit screenshotFailed(QStringLiteral("KDE global shortcuts are unavailable"));
        return false;
    }

    const QDBusReply<QStringList> actionReply = globalAccel.call(
        QStringLiteral("action"), shortcutKey);
    if (!actionReply.isValid() || actionReply.value().size() < 2) {
        emit screenshotFailed(QStringLiteral("No action is assigned to Meta+Shift+S"));
        return false;
    }

    const QString componentName = actionReply.value().at(0);
    const QString actionName = actionReply.value().at(1);
    const QDBusReply<QDBusObjectPath> componentReply = globalAccel.call(
        QStringLiteral("getComponent"), componentName);
    if (!componentReply.isValid()) {
        emit screenshotFailed(QStringLiteral("Could not find the configured screenshot action"));
        return false;
    }

    QDBusInterface component(
        QStringLiteral("org.kde.kglobalaccel"),
        componentReply.value().path(),
        QStringLiteral("org.kde.kglobalaccel.Component"),
        QDBusConnection::sessionBus());
    if (!component.isValid()) {
        emit screenshotFailed(QStringLiteral("Could not open the configured screenshot action"));
        return false;
    }

    const QDBusMessage result = component.call(QStringLiteral("invokeShortcut"), actionName);
    if (result.type() == QDBusMessage::ErrorMessage) {
        emit screenshotFailed(result.errorMessage());
        return false;
    }
    return true;
}

} // namespace ciderdeck
