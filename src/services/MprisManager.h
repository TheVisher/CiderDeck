#pragma once

#include <QObject>
#include <QMap>
#include <QSet>
#include <QTimer>
#include <QStringList>
#include <QVariantMap>

#include <functional>

namespace ciderdeck {

class MprisPropertiesRelay : public QObject {
    Q_OBJECT

public:
    explicit MprisPropertiesRelay(QString service, QObject *parent = nullptr);

signals:
    void propertiesChanged(const QString &service, const QString &interface,
                           const QVariantMap &changed, const QStringList &invalidated);

private slots:
    void forwardPropertiesChanged(const QString &interface, const QVariantMap &changed,
                                  const QStringList &invalidated);

private:
    QString service_;
};

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
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY controlsChanged)
    Q_PROPERTY(QString loopStatus READ loopStatus NOTIFY controlsChanged)
    Q_PROPERTY(bool isSpotify READ isSpotify NOTIFY currentPlayerChanged)
    Q_PROPERTY(QString playerIcon READ playerIcon NOTIFY currentPlayerChanged)
    Q_PROPERTY(int playerCount READ playerCount NOTIFY playersChanged)

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
    bool shuffle() const { return shuffle_; }
    QString loopStatus() const { return loopStatus_; }
    bool isSpotify() const;
    QString playerIcon() const;
    int playerCount() const { return playerNames_.size(); }
    static QString resolvePreferredPlayer(const QStringList &availablePlayers,
                                          const QString &preferredPlayer);
    static QString resolveAutoPlayer(const QStringList &availablePlayers,
                                     const QMap<QString, QString> &playbackStatuses,
                                     const QString &currentPlayer);
    static bool isCurrentService(const QString &sourceService, const QString &currentService);
    static bool isCurrentRequest(const QString &requestService, const QString &currentService,
                                 quint64 requestGeneration, quint64 currentGeneration,
                                 quint64 requestId, quint64 latestRequestId);
    static qlonglong resolveDuration(const QVariantMap &metadata,
                                     const QString &previousIdentity,
                                     qlonglong previousDuration);

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seek(qlonglong offsetUs);
    Q_INVOKABLE void setPosition(qlonglong positionUs);
    Q_INVOKABLE void selectNextPlayer();
    Q_INVOKABLE void selectPreviousPlayer();
    Q_INVOKABLE void selectPreferredPlayer(const QString &name);
    Q_INVOKABLE void applyPreferredPlayer(const QString &name);
    Q_INVOKABLE void toggleShuffle();
    Q_INVOKABLE void cycleLoopStatus();
    Q_INVOKABLE void skipForward(int seconds);
    Q_INVOKABLE void skipBackward(int seconds);

    Q_PROPERTY(QString desktopEntry READ desktopEntry NOTIFY currentPlayerChanged)
    QString desktopEntry() const { return desktopEntry_; }

signals:
    void playersChanged();
    void currentPlayerChanged();
    void metadataChanged();
    void playbackStatusChanged();
    void positionChanged();
    void controlsChanged();

private slots:
    void onNameOwnerChanged(const QString &service, const QString &oldOwner, const QString &newOwner);
    void pollPosition();

private:
    void discoverPlayers();
    void updateDiscoveredPlayers(const QStringList &services);
    void selectBestPlayer();
    void registerPlayer(const QString &name, const QString &service);
    void unregisterPlayer(const QString &name);
    void refreshAutoSelection();
    void settleAutoSelectionProbe(const QString &service, quint64 generation);
    void finishAutoSelectionRefresh(quint64 generation);
    void cancelAutoSelectionRefresh();
    void handlePropertiesChanged(const QString &service, const QString &interface,
                                 const QVariantMap &changed, const QStringList &invalidated);
    void fetchMetadata();
    void fetchPlaybackStatus();
    void fetchPosition();
    void fetchControls();
    void fetchDesktopEntry();
    void requestProperty(const QString &service, const QString &property,
                         const std::function<void(const QVariant &)> &handler);
    void resetPlayerState();
    QString serviceName() const;

    QTimer *positionTimer_ = nullptr;

    QStringList playerNames_;
    QString currentPlayer_;
    QMap<QString, QString> serviceMap_; // display name -> dbus service
    QMap<QString, QString> playbackStatuses_;
    QMap<QString, MprisPropertiesRelay *> propertyRelays_;
    bool autoSelection_ = true;
    quint64 selectionGeneration_ = 0;
    quint64 nextRequestId_ = 0;
    QMap<QString, quint64> latestRequestIds_;
    QMap<QString, quint64> latestAutoStatusRequestIds_;
    quint64 autoSelectionGeneration_ = 0;
    QSet<QString> pendingAutoSelectionServices_;
    QString autoSelectionStartPlayer_;
    bool autoSelectionRefreshActive_ = false;
    bool autoSelectionDeadlineReached_ = false;

    // Metadata
    QString title_;
    QString artist_;
    QString album_;
    QString artUrl_;
    QString trackId_;
    QString desktopEntry_;
    QString metadataIdentity_;
    QString playbackStatus_;
    qlonglong position_ = 0;
    qlonglong duration_ = 0;
    bool canGoNext_ = false;
    bool canGoPrevious_ = false;
    bool canPlay_ = false;
    bool canPause_ = false;
    bool canSeek_ = false;
    bool shuffle_ = false;
    QString loopStatus_ = QStringLiteral("None");
};

} // namespace ciderdeck
