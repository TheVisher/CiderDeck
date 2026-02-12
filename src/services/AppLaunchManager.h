#pragma once

#include <QObject>

namespace ciderdeck {

class AppLaunchManager : public QObject {
    Q_OBJECT

public:
    explicit AppLaunchManager(QObject *parent = nullptr);

    Q_INVOKABLE void launch(const QString &desktopFile, const QString &command = QString());
    Q_INVOKABLE QString iconNameForDesktop(const QString &desktopFile) const;
    Q_INVOKABLE QString appNameForDesktop(const QString &desktopFile) const;

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
};

} // namespace ciderdeck
