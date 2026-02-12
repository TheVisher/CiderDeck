#include "KWinDBusClient.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryFile>
#include <QUuid>
#include <QTextStream>

namespace ciderdeck {

namespace {

QString escapeJsString(QString input) {
    input.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
    input.replace(QStringLiteral("\""), QStringLiteral("\\\""));
    input.replace(QStringLiteral("\n"), QStringLiteral("\\n"));
    input.replace(QStringLiteral("\r"), QStringLiteral("\\r"));
    return input;
}

QString helperFunctions() {
    return QStringLiteral(R"JS(
function ciderdeckFindWindowById(windowId) {
    var id = String(windowId);
    var windows = workspace.windowList();
    for (var i = 0; i < windows.length; ++i) {
        if (String(windows[i].internalId) === id) {
            return windows[i];
        }
    }
    return null;
}
)JS");
}

} // namespace

KWinDBusClient::KWinDBusClient(QObject *parent)
    : QObject(parent) {}

bool KWinDBusClient::publishService() {
    if (servicePublished_) return true;

    auto bus = QDBusConnection::sessionBus();

    if (!bus.registerService(QStringLiteral("org.ciderdeck.App"))) {
        emit bridgeError(QStringLiteral("Failed to register org.ciderdeck.App DBus service"));
        return false;
    }

    if (!bus.registerObject(QStringLiteral("/CiderDeck"), this, QDBusConnection::ExportAllSlots)) {
        emit bridgeError(QStringLiteral("Failed to register /CiderDeck object"));
        return false;
    }

    servicePublished_ = true;
    qInfo() << "[KWinDBusClient] DBus bridge ready: org.ciderdeck.App /CiderDeck";
    return true;
}

bool KWinDBusClient::sendCommand(const QString &method, const QVariantList &arguments) {
    QString scriptBody;

    if (method == "ciderdeckRequestWindowList") {
        scriptBody = QStringLiteral(R"JS(
var windows = workspace.windowList()
    .filter(function(w) { return w && !w.desktopWindow && !w.dock && !w.skipTaskbar; })
    .map(function(w) {
        var activeWin = workspace.activeWindow;
        return {
            id: String(w.internalId),
            caption: String(w.caption || ""),
            resourceClass: String(w.resourceClass || ""),
            desktopFile: String(w.desktopFileName || ""),
            pid: Number(w.pid || 0),
            outputName: String(w.output ? w.output.name : ""),
            minimized: Boolean(w.minimized),
            active: Boolean(activeWin && String(w.internalId) === String(activeWin.internalId))
        };
    });
callDBus("org.ciderdeck.App", "/CiderDeck", "org.ciderdeck.KWinBridge", "pushWindows", JSON.stringify({ windows: windows }));
)JS");
    } else if (method == "ciderdeckFocusWindow") {
        if (arguments.isEmpty()) return false;
        const auto targetId = escapeJsString(arguments.at(0).toString());
        scriptBody = helperFunctions() + QStringLiteral(R"JS(
var target = ciderdeckFindWindowById("%1");
if (target) { workspace.activeWindow = target; }
)JS").arg(targetId);
    } else if (method == "ciderdeckActivateWindow") {
        // Same as focus but also un-minimize
        if (arguments.isEmpty()) return false;
        const auto targetId = escapeJsString(arguments.at(0).toString());
        scriptBody = helperFunctions() + QStringLiteral(R"JS(
var target = ciderdeckFindWindowById("%1");
if (target) {
    if (target.minimized) target.minimized = false;
    workspace.activeWindow = target;
}
)JS").arg(targetId);
    } else if (method == "ciderdeckMoveToScreen") {
        if (arguments.size() < 2) return false;
        const auto targetId = escapeJsString(arguments.at(0).toString());
        const auto screenName = escapeJsString(arguments.at(1).toString());
        scriptBody = helperFunctions() + QStringLiteral(R"JS(
var target = ciderdeckFindWindowById("%1");
if (target) {
    var outputs = workspace.screens;
    for (var i = 0; i < outputs.length; ++i) {
        if (String(outputs[i].name) === "%2") {
            var screen = outputs[i];
            target.output = screen;

            // If the window is on a different screen or newly opened,
            // set geometry with padding so it doesn't fill the screen
            var geom = screen.geometry;
            var pad = 20;
            var targetW = geom.width - 2 * pad;
            var targetH = geom.height - 2 * pad;

            // Only resize if the window is currently larger than the target
            // (avoids shrinking small dialogs)
            var fw = target.frameGeometry;
            if (fw.width > targetW || fw.height > targetH) {
                target.frameGeometry = Qt.rect(
                    geom.x + pad,
                    geom.y + pad,
                    Math.min(fw.width, targetW),
                    Math.min(fw.height, targetH)
                );
            } else {
                // Center the window on the target screen
                target.frameGeometry = Qt.rect(
                    geom.x + (geom.width - fw.width) / 2,
                    geom.y + (geom.height - fw.height) / 2,
                    fw.width,
                    fw.height
                );
            }
            break;
        }
    }
    workspace.activeWindow = target;
}
)JS").arg(targetId, screenName);
    } else {
        emit bridgeError(QStringLiteral("Unknown command: ") + method);
        return false;
    }

    QTemporaryFile scriptFile(QDir::tempPath() + QStringLiteral("/ciderdeck-cmd-XXXXXX.js"));
    scriptFile.setAutoRemove(true);
    if (!scriptFile.open()) {
        emit bridgeError(QStringLiteral("Failed to create temporary KWin script file"));
        return false;
    }

    QTextStream stream(&scriptFile);
    stream << scriptBody;
    stream.flush();
    scriptFile.flush();

    const QString pluginName = QStringLiteral("ciderdeck-cmd-%1")
                                   .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));

    QDBusInterface scripting(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/Scripting"),
        QStringLiteral("org.kde.kwin.Scripting"),
        QDBusConnection::sessionBus());

    if (!scripting.isValid()) {
        emit bridgeError(QStringLiteral("KWin scripting interface unavailable"));
        return false;
    }

    QDBusReply<int> loadReply = scripting.call(QStringLiteral("loadScript"), scriptFile.fileName(), pluginName);
    if (!loadReply.isValid()) {
        emit bridgeError(QStringLiteral("loadScript failed: ") + loadReply.error().message());
        return false;
    }

    QDBusMessage startMsg = scripting.call(QStringLiteral("start"));
    if (startMsg.type() == QDBusMessage::ErrorMessage) {
        emit bridgeError(QStringLiteral("start failed: ") + startMsg.errorMessage());
        return false;
    }

    QDBusReply<bool> unloadReply = scripting.call(QStringLiteral("unloadScript"), pluginName);
    if (!unloadReply.isValid()) {
        emit bridgeError(QStringLiteral("unloadScript failed: ") + unloadReply.error().message());
        return false;
    }

    return true;
}

void KWinDBusClient::pushWindows(const QString &jsonPayload) {
    const auto doc = QJsonDocument::fromJson(jsonPayload.toUtf8());

    if (doc.isObject()) {
        const auto obj = doc.object();
        if (obj.contains("windows")) {
            windows_ = obj["windows"].toArray();
            emit windowPayloadReceived(windows_);
            emit windowsChanged();
            return;
        }
    }

    if (doc.isArray()) {
        windows_ = doc.array();
        emit windowPayloadReceived(windows_);
        emit windowsChanged();
        return;
    }

    emit bridgeError(QStringLiteral("Malformed window payload"));
}

bool KWinDBusClient::requestWindowList() {
    return sendCommand(QStringLiteral("ciderdeckRequestWindowList"));
}

bool KWinDBusClient::focusWindowById(const QString &windowId) {
    return sendCommand(QStringLiteral("ciderdeckFocusWindow"), {windowId});
}

bool KWinDBusClient::activateWindowById(const QString &windowId) {
    return sendCommand(QStringLiteral("ciderdeckActivateWindow"), {windowId});
}

bool KWinDBusClient::moveWindowToScreen(const QString &windowId, const QString &screenName) {
    return sendCommand(QStringLiteral("ciderdeckMoveToScreen"), {windowId, screenName});
}

bool KWinDBusClient::isAppRunning(const QString &resourceClass) const {
    return !findWindowByClass(resourceClass).isEmpty();
}

QString KWinDBusClient::findWindowByClass(const QString &resourceClass) const {
    const QString lower = resourceClass.toLower();
    for (const auto &val : windows_) {
        const auto win = val.toObject();
        if (win["resourceClass"].toString().toLower() == lower) {
            return win["id"].toString();
        }
    }
    return {};
}

QString KWinDBusClient::findWindowByDesktopName(const QString &desktopName) const {
    const QString lower = desktopName.toLower();
    for (const auto &val : windows_) {
        const auto win = val.toObject();
        if (win["desktopFile"].toString().toLower() == lower) {
            return win["id"].toString();
        }
    }
    return {};
}

QString KWinDBusClient::findWindowBest(const QString &wmClass, const QString &desktopName) const {
    // 1. Exact resourceClass match
    QString id = findWindowByClass(wmClass);
    if (!id.isEmpty()) return id;

    // 2. Exact desktopFile match
    if (!desktopName.isEmpty()) {
        id = findWindowByDesktopName(desktopName);
        if (!id.isEmpty()) return id;
    }

    // 3. Partial resourceClass match (contains)
    const QString lower = wmClass.toLower();
    for (const auto &val : windows_) {
        const auto win = val.toObject();
        const QString rc = win["resourceClass"].toString().toLower();
        if (rc.contains(lower) || lower.contains(rc)) {
            return win["id"].toString();
        }
    }

    return {};
}

} // namespace ciderdeck
