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
function ciderdeckDebug(msg) {
    callDBus("org.ciderdeck.App", "/CiderDeck", "org.ciderdeck.KWinBridge", "pushDebug", msg);
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
    var screenFound = false;
    var outputs = workspace.screens;
    var screenCount = outputs.length;
    ciderdeckDebug("MoveToScreen: window found, screens=" + screenCount + " looking for '%2'");

    for (var i = 0; i < screenCount; ++i) {
        var sname = String(outputs[i].name);
        ciderdeckDebug("  screen[" + i + "]: " + sname);
        if (sname === "%2") {
            var screen = outputs[i];
            var geom = screen.geometry;

            // Move the window by setting its geometry to be within the target screen
            var fw = target.frameGeometry;
            var pad = 20;
            var maxW = geom.width - 2 * pad;
            var maxH = geom.height - 2 * pad;
            var newW = Math.min(fw.width, maxW);
            var newH = Math.min(fw.height, maxH);
            var newX = geom.x + Math.round((geom.width - newW) / 2);
            var newY = geom.y + Math.round((geom.height - newH) / 2);

            // Set output first, then geometry
            target.output = screen;
            target.frameGeometry.x = newX;
            target.frameGeometry.y = newY;
            target.frameGeometry.width = newW;
            target.frameGeometry.height = newH;

            screenFound = true;
            ciderdeckDebug("MoveToScreen: moved to " + sname + " geom=" + newX + "," + newY + " " + newW + "x" + newH);
            break;
        }
    }
    if (!screenFound) {
        ciderdeckDebug("MoveToScreen: screen '%2' not found among " + screenCount + " outputs");
    }
    workspace.activeWindow = target;
} else {
    ciderdeckDebug("MoveToScreen: window '%1' not found");
}
)JS").arg(targetId, screenName);
    } else {
        emit bridgeError(QStringLiteral("Unknown command: ") + method);
        return false;
    }

    QTemporaryFile scriptFile(QDir::tempPath() + QStringLiteral("/ciderdeck-cmd-XXXXXX.js"));
    scriptFile.setAutoRemove(false);  // Don't auto-remove, KWin needs the file
    if (!scriptFile.open()) {
        emit bridgeError(QStringLiteral("Failed to create temporary KWin script file"));
        return false;
    }

    const QString scriptPath = scriptFile.fileName();
    QTextStream stream(&scriptFile);
    stream << scriptBody;
    stream.flush();
    scriptFile.flush();
    scriptFile.close();  // Close so KWin can read it

    const QString pluginName = QStringLiteral("ciderdeck-cmd-%1")
                                   .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));

    QDBusInterface scripting(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/Scripting"),
        QStringLiteral("org.kde.kwin.Scripting"),
        QDBusConnection::sessionBus());

    if (!scripting.isValid()) {
        emit bridgeError(QStringLiteral("KWin scripting interface unavailable"));
        QFile::remove(scriptPath);
        return false;
    }

    QDBusReply<int> loadReply = scripting.call(QStringLiteral("loadScript"), scriptPath, pluginName);
    if (!loadReply.isValid()) {
        emit bridgeError(QStringLiteral("loadScript failed: ") + loadReply.error().message());
        QFile::remove(scriptPath);
        return false;
    }

    QDBusMessage startMsg = scripting.call(QStringLiteral("start"));
    if (startMsg.type() == QDBusMessage::ErrorMessage) {
        emit bridgeError(QStringLiteral("start failed: ") + startMsg.errorMessage());
    }

    // Don't unload immediately — give async callDBus time to complete.
    // Schedule cleanup after a short delay via a singleShot timer.
    const QString cleanupPlugin = pluginName;
    const QString cleanupPath = scriptPath;
    QTimer::singleShot(500, this, [cleanupPlugin, cleanupPath]() {
        QDBusInterface scripting(
            QStringLiteral("org.kde.KWin"),
            QStringLiteral("/Scripting"),
            QStringLiteral("org.kde.kwin.Scripting"),
            QDBusConnection::sessionBus());
        if (scripting.isValid()) {
            scripting.call(QStringLiteral("unloadScript"), cleanupPlugin);
        }
        QFile::remove(cleanupPath);
    });

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

void KWinDBusClient::pushDebug(const QString &message) {
    qInfo() << "[KWin Script]" << message;
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
    // Log available windows for debugging
    if (windows_.isEmpty()) {
        qInfo() << "[KWinDBusClient] findWindowBest: window list is empty";
    } else {
        qInfo() << "[KWinDBusClient] findWindowBest: searching for wmClass=" << wmClass
                 << "desktop=" << desktopName << "in" << windows_.size() << "windows:";
        for (const auto &val : windows_) {
            const auto win = val.toObject();
            qInfo() << "  " << win["resourceClass"].toString()
                     << "desktop:" << win["desktopFile"].toString()
                     << "caption:" << win["caption"].toString().left(40);
        }
    }

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
