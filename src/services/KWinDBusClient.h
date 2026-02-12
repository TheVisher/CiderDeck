#pragma once

#include <QObject>
#include <QJsonArray>
#include <QString>
#include <QVariantList>

namespace ciderdeck {

class KWinDBusClient : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.ciderdeck.KWinBridge")

public:
    explicit KWinDBusClient(QObject *parent = nullptr);

    bool publishService();
    bool sendCommand(const QString &method, const QVariantList &arguments = {});

    Q_INVOKABLE bool requestWindowList();
    Q_INVOKABLE bool focusWindowById(const QString &windowId);
    Q_INVOKABLE bool activateWindowById(const QString &windowId);
    Q_INVOKABLE bool moveWindowToScreen(const QString &windowId, const QString &screenName);

    // Check if a window matching a resource class is running
    Q_INVOKABLE bool isAppRunning(const QString &resourceClass) const;
    Q_INVOKABLE QString findWindowByClass(const QString &resourceClass) const;
    Q_INVOKABLE QString findWindowByDesktopName(const QString &desktopName) const;
    Q_INVOKABLE QString findWindowBest(const QString &wmClass, const QString &desktopName) const;

public slots:
    void pushWindows(const QString &jsonPayload);

signals:
    void windowPayloadReceived(const QJsonArray &windows);
    void windowsChanged();
    void bridgeError(const QString &message);

private:
    bool servicePublished_ = false;
    QJsonArray windows_;
};

} // namespace ciderdeck
