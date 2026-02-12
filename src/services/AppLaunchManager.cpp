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
    : QObject(parent) {}

void AppLaunchManager::setKWinClient(KWinDBusClient *client) {
    kwinClient_ = client;
}

void AppLaunchManager::launch(const QString &desktopFile, const QString &command,
                              const QString &targetMonitor, bool raiseExisting) {
    // If raiseExisting, try to find and activate an existing window first
    if (raiseExisting && kwinClient_ && !desktopFile.isEmpty()) {
        auto entry = parseDesktopFile(desktopFile);
        QString wmClass = entry.wmClass;
        if (wmClass.isEmpty()) {
            // Fallback: use desktop file name without .desktop as wmClass guess
            wmClass = desktopFile;
            wmClass.remove(QStringLiteral(".desktop"));
            if (wmClass.contains(QLatin1Char('/'))) {
                wmClass = wmClass.mid(wmClass.lastIndexOf(QLatin1Char('/')) + 1);
            }
        }

        QString windowId = kwinClient_->findWindowByClass(wmClass);
        if (!windowId.isEmpty()) {
            // Window found — activate it and optionally move to target monitor
            if (!targetMonitor.isEmpty()) {
                kwinClient_->moveWindowToScreen(windowId, targetMonitor);
            } else {
                kwinClient_->activateWindowById(windowId);
            }
            emit launched(desktopFile);
            return;
        }
    }

    // If explicit command, use it directly
    if (!command.isEmpty()) {
        bool ok = QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
        if (ok) {
            emit launched(desktopFile);
        } else {
            emit launchFailed(desktopFile, QStringLiteral("Failed to start command"));
        }
        return;
    }

    // If desktop file is a full path, parse and launch the Exec line
    if (desktopFile.contains(QLatin1Char('/'))) {
        auto entry = parseDesktopFile(desktopFile);
        if (!entry.exec.isEmpty()) {
            // Strip field codes like %u %U %f %F from Exec
            QString exec = entry.exec;
            exec.remove(QRegularExpression(QStringLiteral("\\s+%[uUfFdDnNickvm]")));
            bool ok = QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), exec});
            if (ok) {
                emit launched(desktopFile);
            } else {
                emit launchFailed(desktopFile, QStringLiteral("Failed to start application"));
            }
            return;
        }
    }

    // Use gtk-launch for simple desktop file names
    QString name = desktopFile;
    name.remove(QStringLiteral(".desktop"));

    bool ok = QProcess::startDetached(QStringLiteral("gtk-launch"), {name});
    if (ok) {
        emit launched(desktopFile);
    } else {
        emit launchFailed(desktopFile, QStringLiteral("gtk-launch failed"));
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
    // Fallback: derive from desktop file name
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

    // If not a full path, find it
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
