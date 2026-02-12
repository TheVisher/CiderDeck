#include "ScreenshotService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QDateTime>
#include <QStandardPaths>

namespace ciderdeck {

ScreenshotService::ScreenshotService(QObject *parent)
    : QObject(parent) {}

void ScreenshotService::captureScreen(const QString &monitor) {
    Q_UNUSED(monitor)

    QDBusInterface portal("org.freedesktop.portal.Desktop",
                          "/org/freedesktop/portal/desktop",
                          "org.freedesktop.portal.Screenshot",
                          QDBusConnection::sessionBus());

    if (!portal.isValid()) {
        emit screenshotFailed("Screenshot portal not available");
        return;
    }

    QVariantMap options;
    options["interactive"] = false;

    QDBusReply<QDBusObjectPath> reply = portal.call("Screenshot", "", options);
    if (reply.isValid()) {
        emit screenshotSaved(savePath());
    } else {
        emit screenshotFailed("Screenshot failed");
    }
}

void ScreenshotService::captureRegion() {
    QDBusInterface portal("org.freedesktop.portal.Desktop",
                          "/org/freedesktop/portal/desktop",
                          "org.freedesktop.portal.Screenshot",
                          QDBusConnection::sessionBus());

    if (!portal.isValid()) {
        emit screenshotFailed("Screenshot portal not available");
        return;
    }

    QVariantMap options;
    options["interactive"] = true;

    QDBusReply<QDBusObjectPath> reply = portal.call("Screenshot", "", options);
    if (reply.isValid()) {
        emit screenshotSaved(savePath());
    } else {
        emit screenshotFailed("Region capture failed");
    }
}

QString ScreenshotService::savePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
                  + "/CiderDeck";
    QDir().mkpath(dir);
    return dir + "/screenshot_" +
           QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".png";
}

} // namespace ciderdeck
