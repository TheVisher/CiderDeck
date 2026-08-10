#include <QTest>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDBusVirtualObject>

#include "services/MprisManager.h"
#include "services/TimerService.h"
#include "services/UpdateService.h"

#include <utility>

using namespace ciderdeck;

class FakeMprisEndpoint : public QDBusVirtualObject {
public:
    QString playbackStatus_ = QStringLiteral("Paused");
    qlonglong position_ = 0;
    bool canSeek_ = false;
    bool delayPlaybackStatus_ = false;
    bool errorPlaybackStatus_ = false;
    int playbackStatusRequestCount_ = 0;
    int positionRequestCount_ = 0;
    QList<QDBusMessage> delayedPlaybackStatusRequests_;
    QMap<QString, int> methodCalls_;
    QMap<QString, QVariant> propertySets_;

    QString introspect(const QString &path) const override
    {
        Q_UNUSED(path)
        return QStringLiteral(
            "<interface name=\"org.freedesktop.DBus.Properties\">"
            "<method name=\"Get\"><arg type=\"s\" direction=\"in\"/>"
            "<arg type=\"s\" direction=\"in\"/><arg type=\"v\" direction=\"out\"/></method>"
            "<method name=\"GetAll\"><arg type=\"s\" direction=\"in\"/>"
            "<arg type=\"a{sv}\" direction=\"out\"/></method>"
            "<method name=\"Set\"><arg type=\"s\" direction=\"in\"/>"
            "<arg type=\"s\" direction=\"in\"/><arg type=\"v\" direction=\"in\"/></method>"
            "</interface><interface name=\"org.mpris.MediaPlayer2.Player\">"
            "<method name=\"PlayPause\"/><method name=\"Next\"/><method name=\"Previous\"/>"
            "<method name=\"Seek\"><arg type=\"x\" direction=\"in\"/></method>"
            "<method name=\"SetPosition\"><arg type=\"o\" direction=\"in\"/>"
            "<arg type=\"x\" direction=\"in\"/></method></interface>");
    }

    bool handleMessage(const QDBusMessage &message,
                       const QDBusConnection &connection) override
    {
        const QString member = message.member();
        if (message.interface() == QStringLiteral("org.freedesktop.DBus.Properties")) {
            const QList<QVariant> arguments = message.arguments();
            if (member == QStringLiteral("Get")) {
                const QString property = arguments.value(1).toString();
                if (property == QStringLiteral("PlaybackStatus")) {
                    ++playbackStatusRequestCount_;
                    if (delayPlaybackStatus_) {
                        delayedPlaybackStatusRequests_.append(message);
                        return true;
                    }
                    if (errorPlaybackStatus_) {
                        connection.send(message.createErrorReply(
                            QStringLiteral("org.ciderdeck.Test.Error"),
                            QStringLiteral("PlaybackStatus unavailable")));
                        return true;
                    }
                }
                if (property == QStringLiteral("Position"))
                    ++positionRequestCount_;
                connection.send(message.createReply(QList<QVariant>{
                    QVariant::fromValue(QDBusVariant(propertyValue(property)))}));
                return true;
            }
            if (member == QStringLiteral("GetAll")) {
                const QVariantMap values{
                    {QStringLiteral("CanGoNext"), true},
                    {QStringLiteral("CanGoPrevious"), true},
                    {QStringLiteral("CanPlay"), true},
                    {QStringLiteral("CanPause"), true},
                    {QStringLiteral("CanSeek"), canSeek_},
                    {QStringLiteral("Shuffle"), false},
                    {QStringLiteral("LoopStatus"), QStringLiteral("None")},
                };
                connection.send(message.createReply(QList<QVariant>{values}));
                return true;
            }
            if (member == QStringLiteral("Set")) {
                const QDBusVariant value = qvariant_cast<QDBusVariant>(arguments.value(2));
                propertySets_[arguments.value(1).toString()] = value.variant();
                connection.send(message.createReply());
                return true;
            }
        }

        if (message.interface() == QStringLiteral("org.mpris.MediaPlayer2.Player")) {
            ++methodCalls_[member];
            connection.send(message.createReply());
            return true;
        }
        return false;
    }

private:
    QVariant propertyValue(const QString &property) const
    {
        if (property == QStringLiteral("PlaybackStatus"))
            return playbackStatus_;
        if (property == QStringLiteral("CanSeek"))
            return canSeek_;
        if (property == QStringLiteral("Metadata")) {
            return QVariantMap{
                {QStringLiteral("mpris:trackid"),
                 QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/track")))},
                {QStringLiteral("xesam:title"), QStringLiteral("Fake track")},
            };
        }
        if (property == QStringLiteral("DesktopEntry"))
            return QStringLiteral("fake-player");
        if (property == QStringLiteral("LoopStatus"))
            return QStringLiteral("None");
        if (property == QStringLiteral("Position"))
            return position_;
        return property.startsWith(QStringLiteral("Can"));
    }
};

class FakeMprisService {
public:
    FakeMprisService(const QString &playerName, const QString &connectionName)
        : serviceName(QStringLiteral("org.mpris.MediaPlayer2.") + playerName),
          connection(QDBusConnection::connectToBus(QDBusConnection::SessionBus, connectionName))
    {
        QVERIFY(connection.isConnected());
        QVERIFY(connection.registerService(serviceName));
        QVERIFY(connection.registerVirtualObject(QStringLiteral("/org/mpris/MediaPlayer2"),
                                                 &player));
    }

    ~FakeMprisService()
    {
        connection.unregisterObject(QStringLiteral("/org/mpris/MediaPlayer2"));
        connection.unregisterService(serviceName);
        QDBusConnection::disconnectFromBus(connection.name());
    }

    void invalidate(const QStringList &properties)
    {
        QDBusMessage signal = QDBusMessage::createSignal(
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QStringLiteral("PropertiesChanged"));
        signal << QStringLiteral("org.mpris.MediaPlayer2.Player") << QVariantMap{} << properties;
        QVERIFY(connection.send(signal));
    }

    void changePlaybackStatus(const QString &status)
    {
        player.playbackStatus_ = status;
        QDBusMessage signal = QDBusMessage::createSignal(
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QStringLiteral("PropertiesChanged"));
        signal << QStringLiteral("org.mpris.MediaPlayer2.Player")
               << QVariantMap{{QStringLiteral("PlaybackStatus"), status}} << QStringList{};
        QVERIFY(connection.send(signal));
    }

    void releasePlaybackStatusReplies()
    {
        player.delayPlaybackStatus_ = false;
        const QList<QDBusMessage> requests = std::exchange(
            player.delayedPlaybackStatusRequests_, {});
        for (const QDBusMessage &request : requests) {
            QVERIFY(connection.send(request.createReply(QList<QVariant>{
                QVariant::fromValue(QDBusVariant(player.playbackStatus_))})));
        }
    }

    QString serviceName;
    FakeMprisEndpoint player;
    QDBusConnection connection;
};

class ServiceSettingsTests : public QObject {
    Q_OBJECT

private slots:
    void timerDefaultDurationIsApplied();
    void preferredMediaPlayerIsResolved();
    void autoMediaPlayerFollowsPlayback();
    void initialMediaDiscoveryIsAsynchronous();
    void pausedMediaPositionIsFetchedOnce();
    void pausedStatusChangeReconcilesPositionOnce();
    void multiPlayingStartupSelectionIsDeterministic_data();
    void multiPlayingStartupSelectionIsDeterministic();
    void autoSelectionWaitsBoundedlyForDelayedReplies();
    void autoSelectionErrorCompletesArbitration();
    void invalidatedMediaPropertiesAreRefetchedWithoutStaleState();
    void explicitAutoSelectionOverridesManualSelection();
    void delayedAutoProbeSurvivesPlayerReselection();
    void mediaCommandsRouteOnlyToSelectedService();
    void mediaUpdatesAreScopedToSelectedService();
    void staleMediaRepliesAreRejected();
    void mediaDurationSurvivesIncompleteMetadataRefresh();
    void terminalOutputIsMadeReadable();
};

void ServiceSettingsTests::timerDefaultDurationIsApplied()
{
    TimerService timer;
    QCOMPARE(timer.remainingMs(), 5 * 60 * 1000);

    timer.setDuration(12 * 60);
    QCOMPARE(timer.remainingMs(), 12 * 60 * 1000);

    timer.start();
    timer.setDuration(7 * 60);
    timer.pause();
    timer.reset();
    QCOMPARE(timer.remainingMs(), 7 * 60 * 1000);
}

void ServiceSettingsTests::preferredMediaPlayerIsResolved()
{
    const QStringList players{QStringLiteral("firefox.instance1"), QStringLiteral("spotify")};

    QCOMPARE(MprisManager::resolvePreferredPlayer(players, QString()), QStringLiteral("spotify"));
    QCOMPARE(MprisManager::resolvePreferredPlayer(players, QStringLiteral("SPOTIFY")),
             QStringLiteral("spotify"));
    QCOMPARE(MprisManager::resolvePreferredPlayer(players, QStringLiteral("firefox.instance1")),
             QStringLiteral("firefox.instance1"));
    QVERIFY(MprisManager::resolvePreferredPlayer(players, QStringLiteral("missing")).isEmpty());
    QVERIFY(MprisManager::resolvePreferredPlayer({}, QString()).isEmpty());
}

void ServiceSettingsTests::autoMediaPlayerFollowsPlayback()
{
    const QStringList players{QStringLiteral("zen"), QStringLiteral("stremio")};
    const QMap<QString, QString> statuses{
        {QStringLiteral("zen"), QStringLiteral("Paused")},
        {QStringLiteral("stremio"), QStringLiteral("Playing")},
    };

    QCOMPARE(MprisManager::resolveAutoPlayer(players, statuses, QStringLiteral("zen")),
             QStringLiteral("stremio"));
    QCOMPARE(MprisManager::resolveAutoPlayer(players, statuses, QStringLiteral("stremio")),
             QStringLiteral("stremio"));

    const QMap<QString, QString> noPlaying{
        {QStringLiteral("zen"), QStringLiteral("Paused")},
        {QStringLiteral("stremio"), QStringLiteral("Stopped")},
    };
    QCOMPARE(MprisManager::resolveAutoPlayer(players, noPlaying, QStringLiteral("zen")),
             QStringLiteral("zen"));
    QCOMPARE(MprisManager::resolveAutoPlayer(players, noPlaying, QStringLiteral("missing")),
             QStringLiteral("zen"));
}

void ServiceSettingsTests::initialMediaDiscoveryIsAsynchronous()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_discovery_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("discovery-test-") + suffix);

    MprisManager manager;

    QVERIFY2(!manager.playerNames().contains(playerName),
             "constructor must return before initial D-Bus discovery completes");
    QTRY_VERIFY_WITH_TIMEOUT(manager.playerNames().contains(playerName), 2000);
}

void ServiceSettingsTests::pausedMediaPositionIsFetchedOnce()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_paused_position_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("paused-position-test-") + suffix);
    constexpr qlonglong pausedPosition = 1477000000LL;
    service.player.position_ = pausedPosition;

    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.playbackStatus(), QStringLiteral("Paused"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), pausedPosition, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(service.player.positionRequestCount_, 1, 2000);

    QTest::qWait(1100);
    QCOMPARE(service.player.positionRequestCount_, 1);
}

void ServiceSettingsTests::pausedStatusChangeReconcilesPositionOnce()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_paused_change_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("paused-change-test-") + suffix);
    constexpr qlonglong playingPosition = 1000000LL;
    constexpr qlonglong pausedPosition = 1477000000LL;
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = playingPosition;

    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.playbackStatus(), QStringLiteral("Playing"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), playingPosition, 2000);
    const int playingRequestCount = service.player.positionRequestCount_;

    service.player.position_ = pausedPosition;
    service.changePlaybackStatus(QStringLiteral("Paused"));

    QTRY_COMPARE_WITH_TIMEOUT(manager.playbackStatus(), QStringLiteral("Paused"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), pausedPosition, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(service.player.positionRequestCount_, playingRequestCount + 1, 2000);

    QTest::qWait(1100);
    QCOMPARE(service.player.positionRequestCount_, playingRequestCount + 1);
}

void ServiceSettingsTests::multiPlayingStartupSelectionIsDeterministic_data()
{
    QTest::addColumn<bool>("releaseFirstPlayerFirst");
    QTest::addColumn<bool>("releaseAfterDeadline");

    QTest::newRow("first-then-second-before-deadline") << true << false;
    QTest::newRow("second-then-first-before-deadline") << false << false;
    QTest::newRow("first-then-second-after-deadline") << true << true;
    QTest::newRow("second-then-first-after-deadline") << false << true;
}

void ServiceSettingsTests::multiPlayingStartupSelectionIsDeterministic()
{
    QFETCH(bool, releaseFirstPlayerFirst);
    QFETCH(bool, releaseAfterDeadline);

    const QString suffix = QString::number(QCoreApplication::applicationPid())
        + u'_' + QString::fromLatin1(QTest::currentDataTag());
    const QString firstName = QStringLiteral("ciderdeck_test_arbitration_a_") + suffix;
    const QString secondName = QStringLiteral("ciderdeck_test_arbitration_b_") + suffix;
    FakeMprisService first(firstName, QStringLiteral("arbitration-a-") + suffix);
    FakeMprisService second(secondName, QStringLiteral("arbitration-b-") + suffix);
    first.player.playbackStatus_ = QStringLiteral("Playing");
    second.player.playbackStatus_ = QStringLiteral("Playing");
    first.player.delayPlaybackStatus_ = true;
    second.player.delayPlaybackStatus_ = true;

    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), firstName, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(!first.player.delayedPlaybackStatusRequests_.isEmpty(), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(!second.player.delayedPlaybackStatusRequests_.isEmpty(), 2000);

    if (releaseAfterDeadline)
        QTest::qWait(600);

    if (releaseFirstPlayerFirst) {
        first.releasePlaybackStatusReplies();
        QTest::qWait(50);
        second.releasePlaybackStatusReplies();
    } else {
        second.releasePlaybackStatusReplies();
        QTest::qWait(50);
        first.releasePlaybackStatusReplies();
    }

    // With no established current player, Auto deterministically chooses the
    // first Playing service in the sorted player list, regardless of reply order.
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), firstName, 2000);
    QTest::qWait(50);
    QCOMPARE(manager.currentPlayer(), firstName);

    // A later refresh retains an established current player while it is still Playing.
    manager.selectPreferredPlayer(QString());
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), firstName, 2000);
    QTest::qWait(50);
    QCOMPARE(manager.currentPlayer(), firstName);

    first.changePlaybackStatus(QStringLiteral("Paused"));
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), secondName, 2000);
}

void ServiceSettingsTests::autoSelectionWaitsBoundedlyForDelayedReplies()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString delayedName = QStringLiteral("ciderdeck_test_timeout_a_") + suffix;
    const QString playingName = QStringLiteral("ciderdeck_test_timeout_b_") + suffix;
    FakeMprisService delayed(delayedName, QStringLiteral("timeout-a-") + suffix);
    FakeMprisService playing(playingName, QStringLiteral("timeout-b-") + suffix);
    delayed.player.playbackStatus_ = QStringLiteral("Paused");
    delayed.player.delayPlaybackStatus_ = true;
    playing.player.playbackStatus_ = QStringLiteral("Playing");

    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), delayedName, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(!delayed.player.delayedPlaybackStatusRequests_.isEmpty(), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(playing.player.playbackStatusRequestCount_ > 0, 2000);

    QTest::qWait(100);
    QCOMPARE(manager.currentPlayer(), delayedName);
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playingName, 2000);

    delayed.releasePlaybackStatusReplies();
}

void ServiceSettingsTests::autoSelectionErrorCompletesArbitration()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString errorName = QStringLiteral("ciderdeck_test_error_a_") + suffix;
    const QString playingName = QStringLiteral("ciderdeck_test_error_b_") + suffix;
    FakeMprisService error(errorName, QStringLiteral("error-a-") + suffix);
    FakeMprisService playing(playingName, QStringLiteral("error-b-") + suffix);
    error.player.errorPlaybackStatus_ = true;
    playing.player.playbackStatus_ = QStringLiteral("Playing");

    MprisManager manager;

    // An error is a completed barrier response; it must not wait for the deadline.
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playingName, 300);
}

void ServiceSettingsTests::invalidatedMediaPropertiesAreRefetchedWithoutStaleState()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString firstName = QStringLiteral("ciderdeck_test_a_") + suffix;
    const QString secondName = QStringLiteral("ciderdeck_test_b_") + suffix;
    FakeMprisService first(firstName, QStringLiteral("invalidation-a-") + suffix);
    FakeMprisService second(secondName, QStringLiteral("invalidation-b-") + suffix);
    first.player.playbackStatus_ = QStringLiteral("Playing");
    first.player.canSeek_ = true;
    second.player.playbackStatus_ = QStringLiteral("Paused");

    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), firstName, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(manager.canSeek(), 2000);

    first.player.canSeek_ = false;
    first.invalidate({QStringLiteral("CanSeek")});
    QTRY_VERIFY_WITH_TIMEOUT(!manager.canSeek(), 2000);

    second.player.playbackStatus_ = QStringLiteral("Playing");
    second.invalidate({QStringLiteral("PlaybackStatus")});
    first.player.playbackStatus_ = QStringLiteral("Paused");
    first.invalidate({QStringLiteral("PlaybackStatus")});

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), secondName, 2000);
    QVERIFY2(!manager.canSeek(), "CanSeek must not survive invalidation or player reselection");
}

void ServiceSettingsTests::explicitAutoSelectionOverridesManualSelection()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString firstName = QStringLiteral("ciderdeck_test_manual_") + suffix;
    const QString secondName = QStringLiteral("ciderdeck_test_playing_") + suffix;
    FakeMprisService first(firstName, QStringLiteral("auto-a-") + suffix);
    FakeMprisService second(secondName, QStringLiteral("auto-b-") + suffix);
    first.player.playbackStatus_ = QStringLiteral("Paused");
    second.player.playbackStatus_ = QStringLiteral("Playing");

    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), secondName, 2000);
    manager.selectPreferredPlayer(firstName);
    QCOMPARE(manager.currentPlayer(), firstName);

    manager.applyPreferredPlayer(QString());
    QCOMPARE(manager.currentPlayer(), firstName);

    manager.selectPreferredPlayer(QString());

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), secondName, 2000);
}

void ServiceSettingsTests::delayedAutoProbeSurvivesPlayerReselection()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString firstName = QStringLiteral("ciderdeck_test_order_a_") + suffix;
    const QString secondName = QStringLiteral("ciderdeck_test_order_b_") + suffix;
    const QString thirdName = QStringLiteral("ciderdeck_test_order_c_") + suffix;
    FakeMprisService first(firstName, QStringLiteral("ordering-a-") + suffix);
    FakeMprisService second(secondName, QStringLiteral("ordering-b-") + suffix);
    FakeMprisService third(thirdName, QStringLiteral("ordering-c-") + suffix);
    first.player.playbackStatus_ = QStringLiteral("Paused");
    second.player.playbackStatus_ = QStringLiteral("Playing");
    third.player.playbackStatus_ = QStringLiteral("Playing");
    second.player.delayPlaybackStatus_ = true;
    third.player.delayPlaybackStatus_ = true;

    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), firstName, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(!second.player.delayedPlaybackStatusRequests_.isEmpty(), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(!third.player.delayedPlaybackStatusRequests_.isEmpty(), 2000);

    second.releasePlaybackStatusReplies();
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), secondName, 2000);
    third.releasePlaybackStatusReplies();
    QTest::qWait(50);
    second.changePlaybackStatus(QStringLiteral("Paused"));

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), thirdName, 2000);
}

void ServiceSettingsTests::mediaCommandsRouteOnlyToSelectedService()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString selectedName = QStringLiteral("ciderdeck_test_commands_a_") + suffix;
    const QString otherName = QStringLiteral("ciderdeck_test_commands_b_") + suffix;
    FakeMprisService selected(selectedName, QStringLiteral("commands-a-") + suffix);
    FakeMprisService other(otherName, QStringLiteral("commands-b-") + suffix);

    MprisManager manager;
    QTRY_VERIFY_WITH_TIMEOUT(manager.playerNames().contains(selectedName), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(manager.playerNames().contains(otherName), 2000);
    manager.selectPreferredPlayer(selectedName);
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), selectedName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Fake track"), 2000);

    manager.playPause();
    manager.next();
    manager.previous();
    manager.seek(1000000LL);
    manager.setPosition(2000000LL);
    manager.toggleShuffle();
    manager.cycleLoopStatus();

    QTRY_COMPARE_WITH_TIMEOUT(selected.player.methodCalls_.value(QStringLiteral("PlayPause")), 1, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(selected.player.methodCalls_.value(QStringLiteral("Next")), 1, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(selected.player.methodCalls_.value(QStringLiteral("Previous")), 1, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(selected.player.methodCalls_.value(QStringLiteral("Seek")), 1, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(selected.player.methodCalls_.value(QStringLiteral("SetPosition")), 1, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(selected.player.propertySets_.contains(QStringLiteral("Shuffle")), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(selected.player.propertySets_.contains(QStringLiteral("LoopStatus")), 2000);
    QVERIFY(other.player.methodCalls_.isEmpty());
    QVERIFY(other.player.propertySets_.isEmpty());
}

void ServiceSettingsTests::mediaUpdatesAreScopedToSelectedService()
{
    const QString selected = QStringLiteral("org.mpris.MediaPlayer2.stremio");
    QVERIFY(MprisManager::isCurrentService(selected, selected));
    QVERIFY(!MprisManager::isCurrentService(
        QStringLiteral("org.mpris.MediaPlayer2.firefox.instance_1_457"), selected));
    QVERIFY(!MprisManager::isCurrentService(QString(), selected));
}

void ServiceSettingsTests::staleMediaRepliesAreRejected()
{
    const QString selected = QStringLiteral("org.mpris.MediaPlayer2.stremio");
    QVERIFY(MprisManager::isCurrentRequest(selected, selected, 4, 4, 12, 12));
    QVERIFY(!MprisManager::isCurrentRequest(selected, selected, 3, 4, 12, 12));
    QVERIFY(!MprisManager::isCurrentRequest(selected, selected, 4, 4, 11, 12));
    QVERIFY(!MprisManager::isCurrentRequest(
        QStringLiteral("org.mpris.MediaPlayer2.firefox"), selected, 4, 4, 12, 12));
}

void ServiceSettingsTests::mediaDurationSurvivesIncompleteMetadataRefresh()
{
    QVariantMap complete{
        {QStringLiteral("mpris:trackid"), QStringLiteral("/track/1")},
        {QStringLiteral("xesam:url"), QStringLiteral("https://example.test/1")},
        {QStringLiteral("xesam:title"), QStringLiteral("First")},
        {QStringLiteral("mpris:length"), 180000000LL},
    };
    const QString identity = QStringLiteral("/track/1\nhttps://example.test/1\nFirst");

    QCOMPARE(MprisManager::resolveDuration(complete, QString(), 0), 180000000LL);

    complete.remove(QStringLiteral("mpris:length"));
    QCOMPARE(MprisManager::resolveDuration(complete, identity, 180000000LL),
             180000000LL);

    complete[QStringLiteral("xesam:title")] = QStringLiteral("Second");
    QCOMPARE(MprisManager::resolveDuration(complete, identity, 180000000LL), 0LL);
}

void ServiceSettingsTests::terminalOutputIsMadeReadable()
{
    const QByteArray output = "\x1b[1;36mUpdate\x1b[0m\r\n"
                              "Downloading 10%\rDownloading 20%\n"
                              "abc\b\bde\n";
    QCOMPARE(UpdateService::sanitizeTerminalOutput(output),
             QStringLiteral("Update\nDownloading 20%\nade\n"));
}

QTEST_GUILESS_MAIN(ServiceSettingsTests)

#include "ServiceSettingsTests.moc"
