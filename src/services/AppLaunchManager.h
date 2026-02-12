#pragma once

#include <QObject>

namespace ciderdeck {

class KWinDBusClient;

class AppLaunchManager : public QObject {
    Q_OBJECT

public:
    explicit AppLaunchManager(QObject *parent = nullptr);

    void setKWinClient(KWinDBusClient *client);

    Q_INVOKABLE void launch(const QString &desktopFile, const QString &command = QString(),
                            const QString &targetMonitor = QString(), bool raiseExisting = false);
    Q_INVOKABLE QString iconNameForDesktop(const QString &desktopFile) const;
    Q_INVOKABLE QString appNameForDesktop(const QString &desktopFile) const;
    Q_INVOKABLE QString wmClassForDesktop(const QString &desktopFile) const;

    struct DesktopEntry {
        QString name;
        QString icon;
        QString exec;
        QString wmClass;
    };
    DesktopEntry parseDesktopFile(const QString &desktopFile) const;

signals:
    void launched(const QString &desktopFile);
    void launchFailed(const QString &desktopFile, const QString &error);

private:
    QString findDesktopFilePath(const QString &desktopFile) const;
    KWinDBusClient *kwinClient_ = nullptr;
};

} // namespace ciderdeck
