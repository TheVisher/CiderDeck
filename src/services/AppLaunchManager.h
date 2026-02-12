#pragma once

#include <QObject>
#include <QTimer>

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
    void onWindowsChanged();
    QString findDesktopFilePath(const QString &desktopFile) const;

    KWinDBusClient *kwinClient_ = nullptr;

    // Pending move: after launching, watch for the new window and move it
    struct PendingMove {
        QString wmClass;
        QString targetMonitor;
        int retries = 0;
    };
    QList<PendingMove> pendingMoves_;
    QTimer *moveTimer_ = nullptr;
};

} // namespace ciderdeck
