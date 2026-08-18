#include "MprisManager.h"

#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDebug>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>
#include <limits>
#include <utility>

namespace ciderdeck {

static const QString kMprisPrefix = QStringLiteral("org.mpris.MediaPlayer2.");
static const QString kPlayerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");
static const QString kPropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
static constexpr int kAutoSelectionDeadlineMs = 500;

static qlonglong saturatingPositionAdd(qlonglong position, qlonglong offset)
{
    if (offset > 0 && position > std::numeric_limits<qlonglong>::max() - offset)
        return std::numeric_limits<qlonglong>::max();
    if (offset < 0 && position < std::numeric_limits<qlonglong>::min() - offset)
        return std::numeric_limits<qlonglong>::min();
    return position + offset;
}

static void sendAsyncMethod(const QString &service, const QString &interface,
                            const QString &method, const QList<QVariant> &arguments = {})
{
    if (service.isEmpty()) return;
    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"), interface, method);
    message.setArguments(arguments);
    QDBusConnection::sessionBus().asyncCall(message);
}

static void setAsyncPlayerProperty(const QString &service, const QString &property,
                                   const QVariant &value)
{
    sendAsyncMethod(service, kPropertiesInterface, QStringLiteral("Set"),
                    {kPlayerInterface, property,
                     QVariant::fromValue(QDBusVariant(value))});
}

MprisPropertiesRelay::MprisPropertiesRelay(QString service, QObject *parent)
    : QObject(parent), service_(std::move(service))
{
}

void MprisPropertiesRelay::forwardPropertiesChanged(const QString &interface,
                                                     const QVariantMap &changed,
                                                     const QStringList &invalidated)
{
    emit propertiesChanged(service_, interface, changed, invalidated);
}

void MprisPropertiesRelay::forwardSeeked(qlonglong position)
{
    emit seeked(service_, position);
}

static QString youtubeArtworkUrl(const QString &mediaUrl) {
    const QUrl url(mediaUrl);
    const QString host = url.host().toLower();
    QString videoId;

    if (host == QStringLiteral("youtu.be")) {
        videoId = url.path().section('/', 1, 1);
    } else if (host == QStringLiteral("youtube.com")
               || host.endsWith(QStringLiteral(".youtube.com"))) {
        videoId = QUrlQuery(url).queryItemValue(QStringLiteral("v"));
        if (videoId.isEmpty()) {
            const QString section = url.path().section('/', 1, 1);
            if (section == QStringLiteral("shorts")
                || section == QStringLiteral("embed")
                || section == QStringLiteral("live")) {
                videoId = url.path().section('/', 2, 2);
            }
        }
    }

    if (videoId.length() < 6 || videoId.length() > 20) {
        return {};
    }
    for (const QChar c : videoId) {
        if (!c.isLetterOrNumber() && c != u'_' && c != u'-') {
            return {};
        }
    }

    return QStringLiteral("https://i.ytimg.com/vi/%1/hqdefault.jpg").arg(videoId);
}

MprisManager::MprisManager(QObject *parent)
    : QObject(parent) {
    // Watch for ANY new/removed D-Bus services (not just pre-registered ones)
    QDBusConnection::sessionBus().connect(
        QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("/org/freedesktop/DBus"),
        QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("NameOwnerChanged"),
        this, SLOT(onNameOwnerChanged(QString,QString,QString)));

    positionTimer_ = new QTimer(this);
    positionTimer_->setInterval(500);
    connect(positionTimer_, &QTimer::timeout, this, &MprisManager::pollPosition);

    discoverPlayers();
}

void MprisManager::discoverPlayers()
{
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("ListNames"));
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        QDBusPendingReply<QStringList> reply = *watcher;
        watcher->deleteLater();
        if (!reply.isError())
            updateDiscoveredPlayers(reply.value());
    });
}

void MprisManager::updateDiscoveredPlayers(const QStringList &services)
{
    const QStringList oldPlayers = playerNames_;
    playerNames_.clear();

    for (const QString &service : services) {
        if (service.startsWith(kMprisPrefix)) {
            const QString name = service.mid(kMprisPrefix.length());
            playerNames_.append(name);
            registerPlayer(name, service);
        }
    }
    std::sort(playerNames_.begin(), playerNames_.end(), [](const QString &left, const QString &right) {
        return left.compare(right, Qt::CaseInsensitive) < 0;
    });
    for (const QString &oldPlayer : oldPlayers) {
        if (!playerNames_.contains(oldPlayer))
            unregisterPlayer(oldPlayer);
    }

    emit playersChanged();

    if (autoSelection_) {
        refreshAutoSelection();
    } else if (playerNames_.contains(currentPlayer_)) {
        fetchMetadata();
        fetchPlaybackStatus();
        fetchControls();
        fetchDesktopEntry();
    } else {
        autoSelection_ = true;
        refreshAutoSelection();
    }
}

void MprisManager::selectBestPlayer() {
    setCurrentPlayer(resolveAutoPlayer(playerNames_, playbackStatuses_, currentPlayer_));
}

void MprisManager::registerPlayer(const QString &name, const QString &service)
{
    serviceMap_[name] = service;
    if (propertyRelays_.contains(service))
        return;

    auto *relay = new MprisPropertiesRelay(service, this);
    propertyRelays_[service] = relay;
    connect(relay, &MprisPropertiesRelay::propertiesChanged,
            this, &MprisManager::handlePropertiesChanged);
    connect(relay, &MprisPropertiesRelay::seeked,
            this, &MprisManager::handleSeeked);
    QDBusConnection::sessionBus().connect(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("PropertiesChanged"),
        relay, SLOT(forwardPropertiesChanged(QString,QVariantMap,QStringList)));
    QDBusConnection::sessionBus().connect(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPlayerInterface, QStringLiteral("Seeked"),
        relay, SLOT(forwardSeeked(qlonglong)));
}

void MprisManager::unregisterPlayer(const QString &name)
{
    const QString service = serviceMap_.take(name);
    playbackStatuses_.remove(name);
    latestAutoStatusRequestIds_.remove(service);
    if (auto *relay = propertyRelays_.take(service))
        relay->deleteLater();
    settleAutoSelectionProbe(service, autoSelectionGeneration_);
}

QString MprisManager::resolvePreferredPlayer(const QStringList &availablePlayers,
                                              const QString &preferredPlayer) {
    const QString preferred = preferredPlayer.trimmed();
    if (!preferred.isEmpty()) {
        for (const QString &available : availablePlayers) {
            if (available.compare(preferred, Qt::CaseInsensitive) == 0)
                return available;
        }
        return {};
    }

    for (const QString &available : availablePlayers) {
        if (available.compare(QStringLiteral("spotify"), Qt::CaseInsensitive) == 0)
            return available;
    }
    return availablePlayers.isEmpty() ? QString() : availablePlayers.first();
}

QString MprisManager::resolveAutoPlayer(const QStringList &availablePlayers,
                                        const QMap<QString, QString> &playbackStatuses,
                                        const QString &currentPlayer)
{
    QStringList autoPlayers = availablePlayers;
    const auto isPlayerctld = [](const QString &player) {
        return player.compare(QStringLiteral("playerctld"), Qt::CaseInsensitive) == 0;
    };
    if (std::any_of(autoPlayers.cbegin(), autoPlayers.cend(),
                    [&isPlayerctld](const QString &player) { return !isPlayerctld(player); })) {
        autoPlayers.removeIf(isPlayerctld);
    }

    if (autoPlayers.contains(currentPlayer)
        && playbackStatuses.value(currentPlayer) == QStringLiteral("Playing")) {
        return currentPlayer;
    }
    for (const QString &player : autoPlayers) {
        if (playbackStatuses.value(player) == QStringLiteral("Playing"))
            return player;
    }
    if (autoPlayers.contains(currentPlayer))
        return currentPlayer;
    return resolvePreferredPlayer(autoPlayers, QString());
}

bool MprisManager::isCurrentService(const QString &sourceService, const QString &currentService)
{
    return !sourceService.isEmpty() && sourceService == currentService;
}

bool MprisManager::isCurrentRequest(const QString &requestService, const QString &currentService,
                                    quint64 requestGeneration, quint64 currentGeneration,
                                    quint64 requestId, quint64 latestRequestId)
{
    return requestGeneration == currentGeneration
        && requestId == latestRequestId
        && isCurrentService(requestService, currentService);
}

void MprisManager::selectPreferredPlayer(const QString &name) {
    const QString preferred = name.trimmed();
    autoSelection_ = preferred.isEmpty();
    if (autoSelection_) {
        refreshAutoSelection();
        return;
    }
    cancelAutoSelectionRefresh();

    const QString resolved = resolvePreferredPlayer(playerNames_, preferred);
    if (!resolved.isEmpty())
        setCurrentPlayer(resolved);
}

void MprisManager::applyPreferredPlayer(const QString &name)
{
    // Tile creation and player-list refresh are passive. An Auto-configured
    // tile must not erase another tile's still-valid explicit selection.
    if (name.trimmed().isEmpty() && !autoSelection_ && playerNames_.contains(currentPlayer_))
        return;
    selectPreferredPlayer(name);
}

qlonglong MprisManager::resolveDuration(const QVariantMap &metadata,
                                        const QString &previousIdentity,
                                        qlonglong previousDuration) {
    const qlonglong reportedDuration = metadata.value("mpris:length", 0).toLongLong();
    if (reportedDuration > 0)
        return reportedDuration;

    const QString identity = metadata.value("mpris:trackid").toString()
        + u'\n' + metadata.value("xesam:url").toString()
        + u'\n' + metadata.value("xesam:title").toString();
    return identity == previousIdentity ? previousDuration : 0;
}

void MprisManager::setCurrentPlayer(const QString &name) {
    if (currentPlayer_ == name) return;
    ++selectionGeneration_;
    currentPlayer_ = name;
    resetPlayerState();
    emit currentPlayerChanged();

    if (!name.isEmpty()) {
        fetchMetadata();
        fetchPlaybackStatus();
        fetchControls();
        fetchDesktopEntry();
        positionTimer_->start();
    } else {
        positionTimer_->stop();
    }
}

void MprisManager::resetPlayerState()
{
    ++positionRequestEpoch_;
    acceptPlayingZeroPosition_ = false;
    latestRequestIds_.clear();
    title_.clear();
    artist_.clear();
    album_.clear();
    artUrl_.clear();
    trackId_.clear();
    desktopEntry_.clear();
    metadataIdentity_.clear();
    playbackStatus_ = QStringLiteral("Stopped");
    position_ = 0;
    duration_ = 0;
    positionEstimateAnchor_ = 0;
    positionEstimateValid_ = true;
    playingPositionEstimateActive_ = false;
    preservePlayingPositionFromZeroPolls_ = false;
    canGoNext_ = false;
    canGoPrevious_ = false;
    canPlay_ = false;
    canPause_ = false;
    canSeek_ = false;
    shuffle_ = false;
    loopStatus_ = QStringLiteral("None");
    emit metadataChanged();
    emit playbackStatusChanged();
    emit positionChanged();
    emit controlsChanged();
}

void MprisManager::handleSeeked(const QString &service, qlonglong position)
{
    if (!isCurrentService(service, serviceName())) return;
    ++positionRequestEpoch_;
    acceptPlayingZeroPosition_ = false;
    latestRequestIds_[QStringLiteral("Position")] = ++nextRequestId_;
    const qlonglong boundedPosition = this->boundedPosition(position);
    preservePlayingPositionFromZeroPolls_ = playbackStatus_ == QStringLiteral("Playing")
        && boundedPosition > 0;
    setPositionEstimate(boundedPosition);
}

void MprisManager::refreshAutoSelection()
{
    if (!autoSelection_) return;

    const quint64 generation = ++autoSelectionGeneration_;
    autoSelectionRefreshActive_ = true;
    autoSelectionDeadlineReached_ = false;
    autoSelectionStartPlayer_ = currentPlayer_;
    pendingAutoSelectionServices_.clear();
    for (const QString &service : serviceMap_)
        pendingAutoSelectionServices_.insert(service);

    // Show a deterministic fallback immediately when there is no valid
    // selection, but do not treat it as an established Playing player when
    // this refresh is resolved.
    if (!playerNames_.contains(currentPlayer_))
        setCurrentPlayer(resolvePreferredPlayer(playerNames_, QString()));

    if (pendingAutoSelectionServices_.isEmpty()) {
        finishAutoSelectionRefresh(generation);
        return;
    }

    QTimer::singleShot(kAutoSelectionDeadlineMs, this, [this, generation] {
        finishAutoSelectionRefresh(generation);
    });

    for (auto it = serviceMap_.cbegin(); it != serviceMap_.cend(); ++it) {
        const QString player = it.key();
        const QString service = it.value();
        const quint64 requestId = ++nextRequestId_;
        latestAutoStatusRequestIds_[service] = requestId;
        QDBusMessage message = QDBusMessage::createMethodCall(
            service, QStringLiteral("/org/mpris/MediaPlayer2"),
            kPropertiesInterface, QStringLiteral("Get"));
        message << kPlayerInterface << QStringLiteral("PlaybackStatus");
        auto *watcher = new QDBusPendingCallWatcher(
            QDBusConnection::sessionBus().asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this,
                [this, watcher, player, service, requestId, generation] {
            QDBusPendingReply<QVariant> reply = *watcher;
            watcher->deleteLater();
            if (serviceMap_.value(player) != service
                || latestAutoStatusRequestIds_.value(service) != requestId
                || generation != autoSelectionGeneration_) return;
            if (!reply.isError())
                playbackStatuses_[player] = reply.value().toString();
            if (!autoSelection_) return;
            if (autoSelectionRefreshActive_)
                settleAutoSelectionProbe(service, generation);
            else if (!reply.isError())
                selectBestPlayer();
        });
    }
}

void MprisManager::settleAutoSelectionProbe(const QString &service, quint64 generation)
{
    if (!autoSelectionRefreshActive_ || generation != autoSelectionGeneration_)
        return;
    pendingAutoSelectionServices_.remove(service);
    if (pendingAutoSelectionServices_.isEmpty()) {
        setCurrentPlayer(resolveAutoPlayer(
            playerNames_, playbackStatuses_, autoSelectionStartPlayer_));
        autoSelectionRefreshActive_ = false;
        autoSelectionDeadlineReached_ = false;
        autoSelectionStartPlayer_.clear();
    } else if (autoSelectionDeadlineReached_) {
        // The bounded deadline permits a provisional result, while later
        // replies from this generation continue deterministic recomputation.
        setCurrentPlayer(resolveAutoPlayer(
            playerNames_, playbackStatuses_, autoSelectionStartPlayer_));
    }
}

void MprisManager::finishAutoSelectionRefresh(quint64 generation)
{
    if (!autoSelection_ || !autoSelectionRefreshActive_
        || generation != autoSelectionGeneration_) return;

    autoSelectionDeadlineReached_ = true;
    setCurrentPlayer(resolveAutoPlayer(
        playerNames_, playbackStatuses_, autoSelectionStartPlayer_));
}

void MprisManager::cancelAutoSelectionRefresh()
{
    ++autoSelectionGeneration_;
    autoSelectionRefreshActive_ = false;
    autoSelectionDeadlineReached_ = false;
    pendingAutoSelectionServices_.clear();
    autoSelectionStartPlayer_.clear();
}

void MprisManager::onNameOwnerChanged(const QString &service,
                                       const QString &oldOwner,
                                       const QString &newOwner) {
    if (!service.startsWith(kMprisPrefix)) return;

    QString name = service.mid(kMprisPrefix.length());

    if (oldOwner.isEmpty() && !newOwner.isEmpty()) {
        // New player appeared
        if (!playerNames_.contains(name)) {
            playerNames_.append(name);
            std::sort(playerNames_.begin(), playerNames_.end(), [](const QString &left,
                                                                   const QString &right) {
                return left.compare(right, Qt::CaseInsensitive) < 0;
            });
            registerPlayer(name, service);
            emit playersChanged();
        }
        if (autoSelection_)
            refreshAutoSelection();
    } else if (!oldOwner.isEmpty() && newOwner.isEmpty()) {
        // Player disappeared
        playerNames_.removeAll(name);
        unregisterPlayer(name);
        emit playersChanged();
        if (currentPlayer_ == name) {
            if (!autoSelection_)
                autoSelection_ = true;
            refreshAutoSelection();
        }
    } else if (!oldOwner.isEmpty() && !newOwner.isEmpty()) {
        // The well-known name now points to a different process. Invalidate
        // replies sent to the old owner even though the service string is unchanged.
        playbackStatuses_.remove(name);
        if (currentPlayer_ == name) {
            ++selectionGeneration_;
            resetPlayerState();
            emit currentPlayerChanged();
            fetchMetadata();
            fetchPlaybackStatus();
            fetchControls();
            fetchDesktopEntry();
        }
        if (autoSelection_)
            refreshAutoSelection();
    }
}

void MprisManager::handlePropertiesChanged(const QString &service,
                                           const QString &interface,
                                           const QVariantMap &changed,
                                           const QStringList &invalidated) {
    if (interface != kPlayerInterface) return;

    const QString player = serviceMap_.key(service);
    if (player.isEmpty()) return;

    const bool playbackInvalidated = invalidated.contains(QStringLiteral("PlaybackStatus"));
    if (changed.contains(QStringLiteral("PlaybackStatus"))) {
        latestAutoStatusRequestIds_[service] = ++nextRequestId_;
        playbackStatuses_[player] = changed[QStringLiteral("PlaybackStatus")].toString();
        if (autoSelection_) {
            if (autoSelectionRefreshActive_)
                settleAutoSelectionProbe(service, autoSelectionGeneration_);
            else
                selectBestPlayer();
        }
    } else if (playbackInvalidated) {
        latestAutoStatusRequestIds_[service] = ++nextRequestId_;
        playbackStatuses_.remove(player);
        if (autoSelection_)
            refreshAutoSelection();
    }
    if (!isCurrentService(service, serviceName())) return;

    const QStringList controlProperties{
        QStringLiteral("CanGoNext"), QStringLiteral("CanGoPrevious"),
        QStringLiteral("CanPlay"), QStringLiteral("CanPause"),
        QStringLiteral("CanSeek"), QStringLiteral("Shuffle"), QStringLiteral("LoopStatus")};
    for (const QString &property : changed.keys())
        latestRequestIds_[property] = ++nextRequestId_;
    for (const QString &property : invalidated)
        latestRequestIds_[property] = ++nextRequestId_;
    for (const QString &property : controlProperties) {
        if (changed.contains(property) || invalidated.contains(property)) {
            latestRequestIds_[QStringLiteral("Controls")] = ++nextRequestId_;
            break;
        }
    }

    bool controlsChanged = false;
    auto clearInvalidatedBool = [&](const QString &key, bool &field) {
        if (invalidated.contains(key) && field) {
            field = false;
            controlsChanged = true;
        }
    };
    clearInvalidatedBool(QStringLiteral("CanGoNext"), canGoNext_);
    clearInvalidatedBool(QStringLiteral("CanGoPrevious"), canGoPrevious_);
    clearInvalidatedBool(QStringLiteral("CanPlay"), canPlay_);
    clearInvalidatedBool(QStringLiteral("CanPause"), canPause_);
    clearInvalidatedBool(QStringLiteral("CanSeek"), canSeek_);
    clearInvalidatedBool(QStringLiteral("Shuffle"), shuffle_);
    if (invalidated.contains(QStringLiteral("LoopStatus"))
        && loopStatus_ != QStringLiteral("None")) {
        loopStatus_ = QStringLiteral("None");
        controlsChanged = true;
    }

    if (changed.contains(QStringLiteral("PlaybackStatus"))) {
        const QString newStatus = changed[QStringLiteral("PlaybackStatus")].toString();
        updatePlaybackStatus(newStatus);
        if (newStatus != QStringLiteral("Playing"))
            fetchPosition();
    } else if (playbackInvalidated) {
        updatePlaybackStatus(QStringLiteral("Stopped"));
        fetchPlaybackStatus();
    }

    if (changed.contains(QStringLiteral("Metadata"))
        || invalidated.contains(QStringLiteral("Metadata"))) {
        fetchMetadata();
    } else if (changed.contains(QStringLiteral("PlaybackStatus"))) {
        // Already handled above, but also refresh controls
        fetchControls();
    }

    // Handle other property changes
    auto updateBool = [&](const QString &key, bool &field) {
        if (changed.contains(key)) {
            const bool val = changed[key].toBool();
            if (field != val) { field = val; controlsChanged = true; }
        }
    };
    updateBool(QStringLiteral("CanGoNext"), canGoNext_);
    updateBool(QStringLiteral("CanGoPrevious"), canGoPrevious_);
    updateBool(QStringLiteral("CanPlay"), canPlay_);
    updateBool(QStringLiteral("CanPause"), canPause_);
    updateBool(QStringLiteral("CanSeek"), canSeek_);
    updateBool(QStringLiteral("Shuffle"), shuffle_);
    if (changed.contains(QStringLiteral("LoopStatus"))) {
        const QString ls = changed[QStringLiteral("LoopStatus")].toString();
        if (loopStatus_ != ls) { loopStatus_ = ls; controlsChanged = true; }
    }
    if (controlsChanged) emit this->controlsChanged();

    for (const QString &property : controlProperties) {
        if (invalidated.contains(property)) {
            fetchControls();
            break;
        }
    }
}

void MprisManager::fetchMetadata() {
    const quint64 positionEpoch = positionRequestEpoch_;
    requestProperty(serviceName(), QStringLiteral("Metadata"), [this, positionEpoch](const QVariant &value) {
        const QVariantMap metadata = qdbus_cast<QVariantMap>(value.value<QDBusArgument>());
        const QString newIdentity = metadata.value("mpris:trackid").toString()
            + u'\n' + metadata.value("xesam:url").toString()
            + u'\n' + metadata.value("xesam:title").toString();
        const qlonglong newDuration = resolveDuration(metadata, metadataIdentity_, duration_);
        const bool identityChanged = !metadataIdentity_.isEmpty()
            && newIdentity != metadataIdentity_;
        if (identityChanged && positionEpoch == positionRequestEpoch_) {
            ++positionRequestEpoch_;
            acceptPlayingZeroPosition_ = false;
            latestRequestIds_[QStringLiteral("Position")] = ++nextRequestId_;
            positionEstimateValid_ = false;
            playingPositionEstimateActive_ = false;
            preservePlayingPositionFromZeroPolls_ = false;
            if (position_ != 0) {
                position_ = 0;
                emit positionChanged();
            }
        }

        title_ = metadata.value("xesam:title").toString();
        album_ = metadata.value("xesam:album").toString();
        artUrl_ = metadata.value("mpris:artUrl").toString();
        if (artUrl_.isEmpty())
            artUrl_ = youtubeArtworkUrl(metadata.value("xesam:url").toString());
        const QVariant trackId = metadata.value(QStringLiteral("mpris:trackid"));
        if (trackId.canConvert<QDBusObjectPath>())
            trackId_ = qvariant_cast<QDBusObjectPath>(trackId).path();
        else
            trackId_ = trackId.toString();
        metadataIdentity_ = newIdentity;
        const QStringList artists = metadata.value("xesam:artist").toStringList();
        artist_ = artists.isEmpty() ? QString() : artists.join(QStringLiteral(", "));
        duration_ = newDuration;
        emit metadataChanged();
    });
}

void MprisManager::fetchPlaybackStatus() {
    requestProperty(serviceName(), QStringLiteral("PlaybackStatus"), [this](const QVariant &value) {
        const QString newStatus = value.toString();
        const QString player = currentPlayer_;
        playbackStatuses_[player] = newStatus;
        updatePlaybackStatus(newStatus);
        if (autoSelection_ && !autoSelectionRefreshActive_)
            selectBestPlayer();
        if (currentPlayer_ == player && newStatus != QStringLiteral("Playing"))
            fetchPosition();
    });
}

void MprisManager::fetchControls() {
    const QString service = serviceName();
    if (service.isEmpty()) return;
    const quint64 generation = selectionGeneration_;
    const QString requestKey = QStringLiteral("Controls");
    const quint64 requestId = ++nextRequestId_;
    latestRequestIds_[requestKey] = requestId;
    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("GetAll"));
    message << kPlayerInterface;
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, generation, requestKey, requestId] {
        QDBusPendingReply<QVariantMap> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()
            || !isCurrentRequest(service, serviceName(), generation, selectionGeneration_,
                                 requestId, latestRequestIds_.value(requestKey))) return;

        const QVariantMap values = reply.value();
        bool changed = false;
        auto update = [&changed](bool &field, bool value) {
            if (field != value) { field = value; changed = true; }
        };
        update(canGoNext_, values.value("CanGoNext").toBool());
        update(canGoPrevious_, values.value("CanGoPrevious").toBool());
        update(canPlay_, values.value("CanPlay").toBool());
        update(canPause_, values.value("CanPause").toBool());
        update(canSeek_, values.value("CanSeek").toBool());
        update(shuffle_, values.value("Shuffle").toBool());
        const QString loopStatus = values.value("LoopStatus", QStringLiteral("None")).toString();
        if (loopStatus_ != loopStatus) { loopStatus_ = loopStatus; changed = true; }
        if (changed) emit controlsChanged();
    });
}

void MprisManager::pollPosition() {
    if (currentPlayer_.isEmpty() || playbackStatus_ != "Playing") return;
    advancePositionEstimate();
    fetchPosition();
}

void MprisManager::fetchPosition(bool acceptPlayingZero)
{
    const QString service = serviceName();
    if (service.isEmpty()) return;
    const quint64 generation = selectionGeneration_;
    const quint64 epoch = positionRequestEpoch_;
    if (acceptPlayingZero) {
        acceptPlayingZeroPosition_ = true;
        acceptPlayingZeroPositionEpoch_ = epoch;
    }
    const QString property = QStringLiteral("Position");
    const quint64 requestId = ++nextRequestId_;
    latestRequestIds_[property] = requestId;
    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("Get"));
    message << kPlayerInterface << property;
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, generation, epoch, property, requestId] {
        QDBusPendingReply<QVariant> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError() || epoch != positionRequestEpoch_
            || !isCurrentRequest(service, serviceName(), generation, selectionGeneration_,
                                 requestId, latestRequestIds_.value(property))) return;
        const qlonglong newPos = reply.value().toLongLong();
        const bool acceptPlayingZero = acceptPlayingZeroPosition_
            && acceptPlayingZeroPositionEpoch_ == epoch;
        advancePositionEstimate();
        if (!acceptPlayingZero && newPos == 0
            && playbackStatus_ == QStringLiteral("Playing")
            && preservePlayingPositionFromZeroPolls_) return;
        if (!acceptPlayingZero && playbackStatus_ == QStringLiteral("Playing")
            && positionEstimateValid_ && newPos <= estimatedPosition()) return;
        acceptPlayingZeroPosition_ = false;
        if (newPos == 0 || playbackStatus_ != QStringLiteral("Playing"))
            preservePlayingPositionFromZeroPolls_ = false;
        setPositionEstimate(newPos);
    });
}

void MprisManager::updatePlaybackStatus(const QString &status)
{
    if (playbackStatus_ == status) return;

    if (playingPositionEstimateActive_)
        advancePositionEstimate();
    playingPositionEstimateActive_ = false;
    playbackStatus_ = status;
    if (playbackStatus_ == QStringLiteral("Playing") && positionEstimateValid_) {
        positionEstimateAnchor_ = position_;
        positionEstimateTimer_.restart();
        playingPositionEstimateActive_ = true;
    }
    emit playbackStatusChanged();
}

qlonglong MprisManager::boundedPosition(qlonglong position) const
{
    return duration_ > 0
        ? std::clamp(position, 0LL, duration_) : std::max(0LL, position);
}

bool MprisManager::hasValidTrackId() const
{
    if (!trackId_.startsWith(u'/')) return false;
    if (trackId_.size() > 1 && trackId_.endsWith(u'/')) return false;
    for (qsizetype index = 1; index < trackId_.size(); ++index) {
        const QChar character = trackId_.at(index);
        if (character == u'/') {
            if (trackId_.at(index - 1) == u'/') return false;
        } else if (!((character >= u'A' && character <= u'Z')
                     || (character >= u'a' && character <= u'z')
                     || (character >= u'0' && character <= u'9')
                     || character == u'_')) {
            return false;
        }
    }
    return true;
}

qlonglong MprisManager::estimatedPosition() const
{
    if (!playingPositionEstimateActive_ || !positionEstimateTimer_.isValid())
        return boundedPosition(position_);
    return boundedPosition(saturatingPositionAdd(
        positionEstimateAnchor_, positionEstimateTimer_.nsecsElapsed() / 1000LL));
}

void MprisManager::advancePositionEstimate()
{
    const qlonglong estimate = estimatedPosition();
    if (position_ != estimate) {
        position_ = estimate;
        emit positionChanged();
    }
}

void MprisManager::setPositionEstimate(qlonglong position)
{
    const qlonglong bounded = boundedPosition(position);
    positionEstimateAnchor_ = bounded;
    positionEstimateValid_ = true;
    playingPositionEstimateActive_ = playbackStatus_ == QStringLiteral("Playing");
    if (playingPositionEstimateActive_)
        positionEstimateTimer_.restart();
    if (position_ != bounded) {
        position_ = bounded;
        emit positionChanged();
    }
}

void MprisManager::requestProperty(const QString &service, const QString &property,
                                   const std::function<void(const QVariant &)> &handler)
{
    if (service.isEmpty()) return;
    const quint64 generation = selectionGeneration_;
    const quint64 requestId = ++nextRequestId_;
    latestRequestIds_[property] = requestId;
    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("Get"));
    message << kPlayerInterface << property;
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, generation, property, requestId, handler] {
        QDBusPendingReply<QVariant> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()
            || !isCurrentRequest(service, serviceName(), generation, selectionGeneration_,
                                 requestId, latestRequestIds_.value(property))) return;
        handler(reply.value());
    });
}

void MprisManager::playPause() {
    sendAsyncMethod(serviceName(), kPlayerInterface, QStringLiteral("PlayPause"));
}

void MprisManager::next() {
    sendAsyncMethod(serviceName(), kPlayerInterface, QStringLiteral("Next"));
}

void MprisManager::previous() {
    sendAsyncMethod(serviceName(), kPlayerInterface, QStringLiteral("Previous"));
}

void MprisManager::seek(qlonglong offsetUs) {
    sendSeekCommand(QStringLiteral("Seek"), {offsetUs},
                    saturatingPositionAdd(position_, offsetUs));
}

void MprisManager::setPosition(qlonglong positionUs) {
    if (trackId_.isEmpty()) return;
    sendSeekCommand(QStringLiteral("SetPosition"),
                    {QVariant::fromValue(QDBusObjectPath(trackId_)), positionUs}, positionUs);
}

void MprisManager::sendSeekCommand(const QString &method, const QList<QVariant> &arguments,
                                   qlonglong optimisticPosition)
{
    const QString service = serviceName();
    if (service.isEmpty()) return;
    const quint64 generation = selectionGeneration_;
    const quint64 epoch = ++positionRequestEpoch_;
    acceptPlayingZeroPosition_ = false;
    latestRequestIds_[QStringLiteral("Position")] = ++nextRequestId_;
    const qlonglong boundedPosition = this->boundedPosition(optimisticPosition);
    preservePlayingPositionFromZeroPolls_ = playbackStatus_ == QStringLiteral("Playing")
        && boundedPosition > 0;
    setPositionEstimate(boundedPosition);

    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"), kPlayerInterface, method);
    message.setArguments(arguments);
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, generation, epoch] {
        QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (epoch != positionRequestEpoch_
            || generation != selectionGeneration_
            || !isCurrentService(service, serviceName())) return;
        fetchPosition(reply.isError());
    });
}

void MprisManager::selectNextPlayer() {
    if (playerNames_.size() <= 1) return;
    autoSelection_ = false;
    cancelAutoSelectionRefresh();
    int idx = playerNames_.indexOf(currentPlayer_);
    idx = (idx + 1) % playerNames_.size();
    setCurrentPlayer(playerNames_[idx]);
}

void MprisManager::selectPreviousPlayer() {
    if (playerNames_.size() <= 1) return;
    autoSelection_ = false;
    cancelAutoSelectionRefresh();
    int idx = playerNames_.indexOf(currentPlayer_);
    idx = (idx - 1 + playerNames_.size()) % playerNames_.size();
    setCurrentPlayer(playerNames_[idx]);
}

void MprisManager::toggleShuffle() {
    const QString service = serviceName();
    if (service.isEmpty()) return;
    setAsyncPlayerProperty(service, QStringLiteral("Shuffle"), !shuffle_);
    shuffle_ = !shuffle_;
    emit controlsChanged();
}

void MprisManager::cycleLoopStatus() {
    const QString service = serviceName();
    if (service.isEmpty()) return;
    QString next;
    if (loopStatus_ == "None") next = "Track";
    else if (loopStatus_ == "Track") next = "Playlist";
    else next = "None";
    setAsyncPlayerProperty(service, QStringLiteral("LoopStatus"), next);
    loopStatus_ = next;
    emit controlsChanged();
}

void MprisManager::skipForward(int seconds) {
    const qlonglong offset = static_cast<qlonglong>(seconds) * 1000000LL;
    if (hasValidTrackId())
        setPosition(boundedPosition(saturatingPositionAdd(estimatedPosition(), offset)));
    else
        seek(offset);
}

void MprisManager::skipBackward(int seconds) {
    const qlonglong offset = -static_cast<qlonglong>(seconds) * 1000000LL;
    if (hasValidTrackId())
        setPosition(boundedPosition(saturatingPositionAdd(estimatedPosition(), offset)));
    else
        seek(offset);
}

QString MprisManager::playerIcon() const {
    if (currentPlayer_.isEmpty()) return {};
    // Return the player name as an icon name — the AppIconProvider resolves desktop files
    return currentPlayer_ + QStringLiteral(".desktop");
}

void MprisManager::fetchDesktopEntry() {
    const QString service = serviceName();
    if (service.isEmpty()) return;
    const quint64 generation = selectionGeneration_;
    const QString requestKey = QStringLiteral("DesktopEntry");
    const quint64 requestId = ++nextRequestId_;
    latestRequestIds_[requestKey] = requestId;
    QDBusMessage message = QDBusMessage::createMethodCall(
        service, QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("Get"));
    message << QStringLiteral("org.mpris.MediaPlayer2") << QStringLiteral("DesktopEntry");
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service, generation, requestKey, requestId] {
        QDBusPendingReply<QVariant> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()
            || !isCurrentRequest(service, serviceName(), generation, selectionGeneration_,
                                 requestId, latestRequestIds_.value(requestKey))) return;
        QString entry = reply.value().toString();
        if (!entry.isEmpty() && !entry.endsWith(QStringLiteral(".desktop")))
            entry += QStringLiteral(".desktop");
        if (desktopEntry_ != entry) {
            desktopEntry_ = entry;
            emit currentPlayerChanged();
        }
    });
}

bool MprisManager::isSpotify() const {
    return currentPlayer_.toLower().contains("spotify");
}

QString MprisManager::serviceName() const {
    return serviceMap_.value(currentPlayer_);
}

} // namespace ciderdeck
