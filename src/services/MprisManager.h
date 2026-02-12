#pragma once

#include <QObject>
#include <QDBusServiceWatcher>
#include <QDBusInterface>
#include <QTimer>
#include <QStringList>
#include <QVariantMap>

namespace ciderdeck {

class MprisManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList playerNames READ playerNames NOTIFY playersChanged)
    Q_PROPERTY(QString currentPlayer READ currentPlayer WRITE setCurrentPlayer NOTIFY currentPlayerChanged)
    Q_PROPERTY(QString title READ title NOTIFY metadataChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY metadataChanged)
    Q_PROPERTY(QString album READ album NOTIFY metadataChanged)
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY metadataChanged)
    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(qlonglong position READ position NOTIFY positionChanged)
    Q_PROPERTY(qlonglong duration READ duration NOTIFY metadataChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY controlsChanged)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY controlsChanged)
    Q_PROPERTY(bool canPlay READ canPlay NOTIFY controlsChanged)
    Q_PROPERTY(bool canPause READ canPause NOTIFY controlsChanged)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY controlsChanged)
    Q_PROPERTY(bool isSpotify READ isSpotify NOTIFY currentPlayerChanged)

public:
    explicit MprisManager(QObject *parent = nullptr);

    QStringList playerNames() const { return playerNames_; }
    QString currentPlayer() const { return currentPlayer_; }
    void setCurrentPlayer(const QString &name);

    QString title() const { return title_; }
    QString artist() const { return artist_; }
    QString album() const { return album_; }
    QString artUrl() const { return artUrl_; }
    QString playbackStatus() const { return playbackStatus_; }
    qlonglong position() const { return position_; }
    qlonglong duration() const { return duration_; }
    bool canGoNext() const { return canGoNext_; }
    bool canGoPrevious() const { return canGoPrevious_; }
    bool canPlay() const { return canPlay_; }
    bool canPause() const { return canPause_; }
    bool canSeek() const { return canSeek_; }
    bool isSpotify() const;

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seek(qlonglong offsetUs);
    Q_INVOKABLE void setPosition(qlonglong positionUs);

signals:
    void playersChanged();
    void currentPlayerChanged();
    void metadataChanged();
    void playbackStatusChanged();
    void positionChanged();
    void controlsChanged();

private slots:
    void onServiceRegistered(const QString &service);
    void onServiceUnregistered(const QString &service);
    void pollPosition();
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void discoverPlayers();
    void selectBestPlayer();
    void fetchMetadata();
    void fetchPlaybackStatus();
    void fetchControls();
    QString serviceName() const;
    QDBusInterface *playerInterface();

    QDBusServiceWatcher *watcher_ = nullptr;
    QTimer *positionTimer_ = nullptr;

    QStringList playerNames_;
    QString currentPlayer_;
    QMap<QString, QString> serviceMap_; // display name -> dbus service

    // Metadata
    QString title_;
    QString artist_;
    QString album_;
    QString artUrl_;
    QString trackId_;
    QString playbackStatus_;
    qlonglong position_ = 0;
    qlonglong duration_ = 0;
    bool canGoNext_ = false;
    bool canGoPrevious_ = false;
    bool canPlay_ = false;
    bool canPause_ = false;
    bool canSeek_ = false;
};

} // namespace ciderdeck
