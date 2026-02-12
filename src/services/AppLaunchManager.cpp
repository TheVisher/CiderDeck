#include "AppLaunchManager.h"
#include "KWinDBusClient.h"

#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QRegularExpression>

namespace ciderdeck {

AppLaunchManager::AppLaunchManager(QObject *parent)
    : QObject(parent) {
    moveTimer_ = new QTimer(this);
    moveTimer_->setInterval(500);
    connect(moveTimer_, &QTimer::timeout, this, [this]() {
        if (pendingMoves_.isEmpty()) {
            moveTimer_->stop();
            return;
        }
        // Request fresh window list to check for new windows
        if (kwinClient_) {
            kwinClient_->requestWindowList();
        }
    });
}

void AppLaunchManager::setKWinClient(KWinDBusClient *client) {
    kwinClient_ = client;
    if (kwinClient_) {
        connect(kwinClient_, &KWinDBusClient::windowsChanged, this, &AppLaunchManager::onWindowsChanged);
    }
}

void AppLaunchManager::onWindowsChanged() {
    if (pendingMoves_.isEmpty()) return;

    QMutableListIterator<PendingMove> it(pendingMoves_);
    while (it.hasNext()) {
        auto &pending = it.next();
        pending.retries++;

        // Log window list on first retry to help debug matching
        if (pending.retries == 2) {
            qInfo() << "[AppLaunchManager] Looking for wmClass:" << pending.wmClass
                     << "desktop:" << pending.desktopName;
        }

        QString windowId = kwinClient_->findWindowBest(pending.wmClass, pending.desktopName);
        if (!windowId.isEmpty()) {
            qInfo() << "[AppLaunchManager] Moving window" << windowId
                     << "matched:" << pending.wmClass
                     << "(desktop:" << pending.desktopName << ") to" << pending.targetMonitor;
            kwinClient_->moveWindowToScreen(windowId, pending.targetMonitor);
            it.remove();
        } else if (pending.retries > 20) {
            // Give up after ~10 seconds
            qWarning() << "[AppLaunchManager] Timed out waiting for window"
                        << pending.wmClass << "desktop:" << pending.desktopName;
            it.remove();
        }
    }

    if (pendingMoves_.isEmpty()) {
        moveTimer_->stop();
    }
}

void AppLaunchManager::launch(const QString &desktopFile, const QString &command,
                              const QString &targetMonitor, bool raiseExisting) {
    // Derive wmClass and desktopName from the desktop file
    QString wmClass;
    QString desktopName;  // filename without .desktop extension, no path
    if (!desktopFile.isEmpty()) {
        auto entry = parseDesktopFile(desktopFile);
        wmClass = entry.wmClass;
        // Derive desktopName (what KWin reports as desktopFileName)
        desktopName = desktopFile;
        desktopName.remove(QStringLiteral(".desktop"));
        if (desktopName.contains(QLatin1Char('/'))) {
            desktopName = desktopName.mid(desktopName.lastIndexOf(QLatin1Char('/')) + 1);
        }
        if (wmClass.isEmpty()) {
            wmClass = desktopName;
        }
    }

    // If raiseExisting, try to find and activate an existing window first
    if (raiseExisting && kwinClient_ && !desktopFile.isEmpty()) {
        qInfo() << "[AppLaunchManager] raiseExisting: looking for wmClass:" << wmClass
                 << "desktop:" << desktopName;
        QString windowId = kwinClient_->findWindowBest(wmClass, desktopName);
        if (!windowId.isEmpty()) {
            if (!targetMonitor.isEmpty()) {
                kwinClient_->moveWindowToScreen(windowId, targetMonitor);
            } else {
                kwinClient_->activateWindowById(windowId);
            }
            emit launched(desktopFile);
            return;
        }
    }

    bool ok = false;

    // If explicit command, use it directly
    if (!command.isEmpty()) {
        ok = QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
    } else if (desktopFile.contains(QLatin1Char('/'))) {
        // If desktop file is a full path, parse and launch the Exec line
        auto entry = parseDesktopFile(desktopFile);
        if (!entry.exec.isEmpty()) {
            QString exec = entry.exec;
            exec.remove(QRegularExpression(QStringLiteral("\\s+%[uUfFdDnNickvm]")));
            ok = QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), exec});
        }
    } else {
        // Use gtk-launch for simple desktop file names
        QString name = desktopFile;
        name.remove(QStringLiteral(".desktop"));
        ok = QProcess::startDetached(QStringLiteral("gtk-launch"), {name});
    }

    if (ok) {
        emit launched(desktopFile);

        // Queue a pending move if we have a target monitor
        if (!targetMonitor.isEmpty() && kwinClient_ && (!wmClass.isEmpty() || !desktopName.isEmpty())) {
            PendingMove pending;
            pending.wmClass = wmClass;
            pending.desktopName = desktopName;
            pending.targetMonitor = targetMonitor;
            pending.retries = 0;
            pendingMoves_.append(pending);

            if (!moveTimer_->isActive()) {
                moveTimer_->start();
            }
            // Request an immediate window list check
            kwinClient_->requestWindowList();
        }
    } else {
        emit launchFailed(desktopFile, QStringLiteral("Failed to start application"));
    }
}

QString AppLaunchManager::iconNameForDesktop(const QString &desktopFile) const {
    auto entry = parseDesktopFile(desktopFile);
    return entry.icon;
}

QString AppLaunchManager::appNameForDesktop(const QString &desktopFile) const {
    auto entry = parseDesktopFile(desktopFile);
    return entry.name;
}

QString AppLaunchManager::wmClassForDesktop(const QString &desktopFile) const {
    auto entry = parseDesktopFile(desktopFile);
    if (!entry.wmClass.isEmpty()) return entry.wmClass;
    QString name = desktopFile;
    name.remove(QStringLiteral(".desktop"));
    if (name.contains(QLatin1Char('/'))) {
        name = name.mid(name.lastIndexOf(QLatin1Char('/')) + 1);
    }
    return name;
}

AppLaunchManager::DesktopEntry AppLaunchManager::parseDesktopFile(const QString &desktopFile) const {
    DesktopEntry entry;
    QString path = desktopFile;

    if (!desktopFile.contains(QLatin1Char('/'))) {
        path = findDesktopFilePath(desktopFile);
    }

    if (path.isEmpty() || !QFile::exists(path)) {
        return entry;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return entry;
    }

    QTextStream stream(&file);
    bool inDesktopEntry = false;

    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.startsWith(QLatin1Char('['))) {
            inDesktopEntry = (line == QStringLiteral("[Desktop Entry]"));
            continue;
        }
        if (!inDesktopEntry) continue;

        if (line.startsWith(QStringLiteral("Name=")) && entry.name.isEmpty()) {
            entry.name = line.mid(5).trimmed();
        } else if (line.startsWith(QStringLiteral("Icon="))) {
            entry.icon = line.mid(5).trimmed();
        } else if (line.startsWith(QStringLiteral("Exec="))) {
            entry.exec = line.mid(5).trimmed();
        } else if (line.startsWith(QStringLiteral("StartupWMClass="))) {
            entry.wmClass = line.mid(15).trimmed();
        }
    }

    return entry;
}

QString AppLaunchManager::findDesktopFilePath(const QString &desktopFile) const {
    QString filename = desktopFile;
    if (!filename.endsWith(QStringLiteral(".desktop"))) {
        filename += QStringLiteral(".desktop");
    }

    const QStringList dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const QString &dir : dirs) {
        QString fullPath = dir + QLatin1Char('/') + filename;
        if (QFile::exists(fullPath)) {
            return fullPath;
        }
    }

    return {};
}

} // namespace ciderdeck
