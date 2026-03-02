#include "MprisManager.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QDebug>

namespace ciderdeck {

static const QString kMprisPrefix = QStringLiteral("org.mpris.MediaPlayer2.");
static const QString kPlayerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");
static const QString kPropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");

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

    // Connect to PropertiesChanged for any MPRIS player
    QDBusConnection::sessionBus().connect(
        QString(), QStringLiteral("/org/mpris/MediaPlayer2"),
        kPropertiesInterface, QStringLiteral("PropertiesChanged"),
        this, SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));

    discoverPlayers();
}

void MprisManager::discoverPlayers() {
    auto reply = QDBusConnection::sessionBus().interface()->registeredServiceNames();
    if (!reply.isValid()) return;

    playerNames_.clear();
    serviceMap_.clear();

    for (const QString &service : reply.value()) {
        if (service.startsWith(kMprisPrefix)) {
            QString name = service.mid(kMprisPrefix.length());
            playerNames_.append(name);
            serviceMap_[name] = service;
        }
    }

    emit playersChanged();

    if (currentPlayer_.isEmpty() && !playerNames_.isEmpty()) {
        selectBestPlayer();
    } else {
        fetchMetadata();
        fetchPlaybackStatus();
        fetchControls();
    }
}

void MprisManager::selectBestPlayer() {
    if (playerNames_.isEmpty()) {
        setCurrentPlayer(QString());
        return;
    }

    // Prefer Spotify, then first available
    if (playerNames_.contains("spotify")) {
        setCurrentPlayer("spotify");
    } else {
        setCurrentPlayer(playerNames_.first());
    }
}

void MprisManager::setCurrentPlayer(const QString &name) {
    if (currentPlayer_ == name) return;
    currentPlayer_ = name;
    emit currentPlayerChanged();

    if (!name.isEmpty()) {
        fetchMetadata();
        fetchPlaybackStatus();
        fetchControls();
        positionTimer_->start();
    } else {
        positionTimer_->stop();
        title_.clear(); artist_.clear(); album_.clear(); artUrl_.clear();
        playbackStatus_ = "Stopped";
        position_ = 0; duration_ = 0;
        emit metadataChanged();
        emit playbackStatusChanged();
        emit positionChanged();
    }
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
            serviceMap_[name] = service;
            emit playersChanged();
        }
        if (currentPlayer_.isEmpty()) {
            selectBestPlayer();
        }
    } else if (!oldOwner.isEmpty() && newOwner.isEmpty()) {
        // Player disappeared
        playerNames_.removeAll(name);
        serviceMap_.remove(name);
        emit playersChanged();
        if (currentPlayer_ == name) {
            selectBestPlayer();
        }
    }
}

void MprisManager::onPropertiesChanged(const QString &interface,
                                        const QVariantMap &changed,
                                        const QStringList &invalidated) {
    Q_UNUSED(invalidated)
    if (interface != kPlayerInterface) return;

    if (changed.contains("PlaybackStatus")) {
        QString newStatus = changed["PlaybackStatus"].toString();
        if (playbackStatus_ != newStatus) {
            playbackStatus_ = newStatus;
            emit playbackStatusChanged();
        }
    }

    if (changed.contains("Metadata")) {
        fetchMetadata();
    } else if (changed.contains("PlaybackStatus")) {
        // Already handled above, but also refresh controls
        fetchControls();
    }

    // Handle other property changes
    bool controlsChanged = false;
    auto updateBool = [&](const QString &key, bool &field) {
        if (changed.contains(key)) {
            bool val = changed[key].toBool();
            if (field != val) { field = val; controlsChanged = true; }
        }
    };
    updateBool("CanGoNext", canGoNext_);
    updateBool("CanGoPrevious", canGoPrevious_);
    updateBool("CanPlay", canPlay_);
    updateBool("CanPause", canPause_);
    updateBool("CanSeek", canSeek_);
    updateBool("Shuffle", shuffle_);
    if (changed.contains("LoopStatus")) {
        QString ls = changed["LoopStatus"].toString();
        if (loopStatus_ != ls) { loopStatus_ = ls; controlsChanged = true; }
    }
    if (controlsChanged) emit this->controlsChanged();
}

void MprisManager::fetchMetadata() {
    if (currentPlayer_.isEmpty()) return;

    QDBusInterface props(serviceName(), "/org/mpris/MediaPlayer2",
                         kPropertiesInterface, QDBusConnection::sessionBus());

    QDBusReply<QVariant> reply = props.call("Get", kPlayerInterface, "Metadata");
    if (!reply.isValid()) return;

    auto metadata = qdbus_cast<QVariantMap>(reply.value().value<QDBusArgument>());

    title_ = metadata.value("xesam:title").toString();
    album_ = metadata.value("xesam:album").toString();
    artUrl_ = metadata.value("mpris:artUrl").toString();
    trackId_ = metadata.value("mpris:trackid").toString();

    auto artists = metadata.value("xesam:artist").toStringList();
    artist_ = artists.isEmpty() ? QString() : artists.join(", ");

    duration_ = metadata.value("mpris:length", 0).toLongLong();

    emit metadataChanged();
    fetchPlaybackStatus();
    fetchControls();
}

void MprisManager::fetchPlaybackStatus() {
    if (currentPlayer_.isEmpty()) return;

    QDBusInterface props(serviceName(), "/org/mpris/MediaPlayer2",
                         kPropertiesInterface, QDBusConnection::sessionBus());

    QDBusReply<QVariant> reply = props.call("Get", kPlayerInterface, "PlaybackStatus");
    if (reply.isValid()) {
        QString newStatus = reply.value().toString();
        if (playbackStatus_ != newStatus) {
            playbackStatus_ = newStatus;
            emit playbackStatusChanged();
        }
    }
}

void MprisManager::fetchControls() {
    if (currentPlayer_.isEmpty()) return;

    QDBusInterface props(serviceName(), "/org/mpris/MediaPlayer2",
                         kPropertiesInterface, QDBusConnection::sessionBus());

    auto getBool = [&](const QString &prop) -> bool {
        QDBusReply<QVariant> r = props.call("Get", kPlayerInterface, prop);
        return r.isValid() ? r.value().toBool() : false;
    };

    bool changed = false;
    auto update = [&](bool &field, bool val) {
        if (field != val) { field = val; changed = true; }
    };

    update(canGoNext_, getBool("CanGoNext"));
    update(canGoPrevious_, getBool("CanGoPrevious"));
    update(canPlay_, getBool("CanPlay"));
    update(canPause_, getBool("CanPause"));
    update(canSeek_, getBool("CanSeek"));
    update(shuffle_, getBool("Shuffle"));

    // Fetch LoopStatus (string, not bool)
    QDBusReply<QVariant> loopReply = props.call("Get", kPlayerInterface, QStringLiteral("LoopStatus"));
    if (loopReply.isValid()) {
        QString ls = loopReply.value().toString();
        if (loopStatus_ != ls) { loopStatus_ = ls; changed = true; }
    }

    if (changed) emit controlsChanged();
}

void MprisManager::pollPosition() {
    if (currentPlayer_.isEmpty() || playbackStatus_ != "Playing") return;

    QDBusInterface props(serviceName(), "/org/mpris/MediaPlayer2",
                         kPropertiesInterface, QDBusConnection::sessionBus());

    QDBusReply<QVariant> reply = props.call("Get", kPlayerInterface, "Position");
    if (reply.isValid()) {
        qlonglong newPos = reply.value().toLongLong();
        if (position_ != newPos) {
            position_ = newPos;
            emit positionChanged();
        }
    }
}

void MprisManager::playPause() {
    auto *iface = playerInterface();
    if (iface) { iface->call("PlayPause"); delete iface; }
}

void MprisManager::next() {
    auto *iface = playerInterface();
    if (iface) { iface->call("Next"); delete iface; }
}

void MprisManager::previous() {
    auto *iface = playerInterface();
    if (iface) { iface->call("Previous"); delete iface; }
}

void MprisManager::seek(qlonglong offsetUs) {
    auto *iface = playerInterface();
    if (iface) { iface->call("Seek", offsetUs); delete iface; }
}

void MprisManager::setPosition(qlonglong positionUs) {
    auto *iface = playerInterface();
    if (iface) { iface->call("SetPosition", QDBusObjectPath(trackId_), positionUs); delete iface; }
}

void MprisManager::selectNextPlayer() {
    if (playerNames_.size() <= 1) return;
    int idx = playerNames_.indexOf(currentPlayer_);
    idx = (idx + 1) % playerNames_.size();
    setCurrentPlayer(playerNames_[idx]);
}

void MprisManager::selectPreviousPlayer() {
    if (playerNames_.size() <= 1) return;
    int idx = playerNames_.indexOf(currentPlayer_);
    idx = (idx - 1 + playerNames_.size()) % playerNames_.size();
    setCurrentPlayer(playerNames_[idx]);
}

void MprisManager::toggleShuffle() {
    auto *iface = playerInterface();
    if (!iface) return;
    // Toggle via D-Bus property
    QDBusInterface props(serviceName(), QStringLiteral("/org/mpris/MediaPlayer2"),
                         kPropertiesInterface, QDBusConnection::sessionBus());
    props.call("Set", kPlayerInterface, QStringLiteral("Shuffle"),
               QVariant::fromValue(QDBusVariant(!shuffle_)));
    shuffle_ = !shuffle_;
    emit controlsChanged();
    delete iface;
}

void MprisManager::cycleLoopStatus() {
    QDBusInterface props(serviceName(), QStringLiteral("/org/mpris/MediaPlayer2"),
                         kPropertiesInterface, QDBusConnection::sessionBus());
    QString next;
    if (loopStatus_ == "None") next = "Track";
    else if (loopStatus_ == "Track") next = "Playlist";
    else next = "None";
    props.call("Set", kPlayerInterface, QStringLiteral("LoopStatus"),
               QVariant::fromValue(QDBusVariant(next)));
    loopStatus_ = next;
    emit controlsChanged();
}

void MprisManager::skipForward(int seconds) {
    seek(static_cast<qlonglong>(seconds) * 1000000LL);
}

void MprisManager::skipBackward(int seconds) {
    seek(-static_cast<qlonglong>(seconds) * 1000000LL);
}

QString MprisManager::playerIcon() const {
    if (currentPlayer_.isEmpty()) return {};
    // Return the player name as an icon name — the AppIconProvider resolves desktop files
    return currentPlayer_ + QStringLiteral(".desktop");
}

QString MprisManager::desktopEntry() const {
    if (currentPlayer_.isEmpty()) return {};

    // Query the org.mpris.MediaPlayer2 interface for DesktopEntry
    QDBusInterface props(serviceMap_.value(currentPlayer_),
                         QStringLiteral("/org/mpris/MediaPlayer2"),
                         kPropertiesInterface, QDBusConnection::sessionBus());
    QDBusReply<QVariant> reply = props.call("Get",
        QStringLiteral("org.mpris.MediaPlayer2"), QStringLiteral("DesktopEntry"));
    if (reply.isValid()) {
        QString entry = reply.value().toString();
        if (!entry.isEmpty() && !entry.endsWith(QStringLiteral(".desktop")))
            entry += QStringLiteral(".desktop");
        return entry;
    }
    return {};
}

bool MprisManager::isSpotify() const {
    return currentPlayer_.toLower().contains("spotify");
}

QString MprisManager::serviceName() const {
    return serviceMap_.value(currentPlayer_);
}

QDBusInterface *MprisManager::playerInterface() {
    if (currentPlayer_.isEmpty()) return nullptr;
    // Caller must delete after use
    return new QDBusInterface(serviceName(), QStringLiteral("/org/mpris/MediaPlayer2"),
                              kPlayerInterface, QDBusConnection::sessionBus());
}

} // namespace ciderdeck
