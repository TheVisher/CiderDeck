#include <QTest>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDBusVirtualObject>
#include <QSignalSpy>
#include <QVariant>

#include "services/MprisManager.h"
#include "services/TimerService.h"
#include "services/UpdateService.h"

#include <limits>
#include <utility>

using namespace ciderdeck;

class FakeMprisEndpoint : public QDBusVirtualObject {
public:
    QString playbackStatus_ = QStringLiteral("Paused");
    qlonglong position_ = 0;
    QVariantMap metadata_{
        {QStringLiteral("mpris:trackid"),
         QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/track")))},
        {QStringLiteral("xesam:title"), QStringLiteral("Fake track")},
    };
    bool canSeek_ = false;
    bool delayPlaybackStatus_ = false;
    bool errorPlaybackStatus_ = false;
    bool delayMetadata_ = false;
    bool delayPosition_ = false;
    QSet<QString> errorMethods_;
    int playbackStatusRequestCount_ = 0;
    int positionRequestCount_ = 0;
    QList<QDBusMessage> delayedPlaybackStatusRequests_;
    QList<QPair<QDBusMessage, QVariantMap>> delayedMetadataRequests_;
    QList<QPair<QDBusMessage, qlonglong>> delayedPositionRequests_;
    QMap<QString, int> methodCalls_;
    QMap<QString, QList<QVariant>> methodArguments_;
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
                if (property == QStringLiteral("Metadata") && delayMetadata_) {
                    delayedMetadataRequests_.append({message, metadata_});
                    return true;
                }
                if (property == QStringLiteral("Position")) {
                    ++positionRequestCount_;
                    if (delayPosition_) {
                        delayedPositionRequests_.append({message, position_});
                        return true;
                    }
                }
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
            methodArguments_[member] = message.arguments();
            if (errorMethods_.contains(member)) {
                connection.send(message.createErrorReply(
                    QStringLiteral("org.ciderdeck.Test.Error"), member + QStringLiteral(" failed")));
                return true;
            }
            if (member == QStringLiteral("Seek"))
                position_ += message.arguments().value(0).toLongLong();
            else if (member == QStringLiteral("SetPosition"))
                position_ = message.arguments().value(1).toLongLong();
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
        if (property == QStringLiteral("Metadata"))
            return metadata_;
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

    void changeMetadata(const QVariantMap &metadata)
    {
        player.metadata_ = metadata;
        QDBusMessage signal = QDBusMessage::createSignal(
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QStringLiteral("PropertiesChanged"));
        signal << QStringLiteral("org.mpris.MediaPlayer2.Player")
               << QVariantMap{{QStringLiteral("Metadata"), metadata}} << QStringList{};
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

    void releaseNextPositionReply()
    {
        QVERIFY(!player.delayedPositionRequests_.isEmpty());
        const auto request = player.delayedPositionRequests_.takeFirst();
        QVERIFY(connection.send(request.first.createReply(QList<QVariant>{
            QVariant::fromValue(QDBusVariant(request.second))})));
    }

    void releaseNextMetadataReply()
    {
        QVERIFY(!player.delayedMetadataRequests_.isEmpty());
        const auto request = player.delayedMetadataRequests_.takeFirst();
        QVERIFY(connection.send(request.first.createReply(QList<QVariant>{
            QVariant::fromValue(QDBusVariant(request.second))})));
    }

    void emitSeeked(qlonglong position)
    {
        player.position_ = position;
        QDBusMessage signal = QDBusMessage::createSignal(
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.mpris.MediaPlayer2.Player"),
            QStringLiteral("Seeked"));
        signal << position;
        QVERIFY(connection.send(signal));
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
    void selectedSeekedIsAppliedAndUnselectedSeekedIsIgnored();
    void playingZeroPollsDoNotOverrideAuthoritativeSeeked();
    void stalledPlayingPositionAdvancesMonotonically();
    void playingPositionEstimateSaturatesAtSignedMaximum();
    void playingSkipForwardUsesAbsoluteEstimatedPosition();
    void playingSkipBackwardUsesAbsoluteEstimatedPosition();
    void absoluteSkipTargetsClampToTrackBounds();
    void absoluteSkipTargetsSaturateAtSignedLimits();
    void invalidTrackIdFallsBackToRelativeSkip();
    void relativeSeekOptimismSaturatesAtSignedLimits();
    void stoppedPositionIsReconciledAndStopsAdvancing();
    void trackChangeStopsThePriorPositionEstimate();
    void backwardSeekedReanchorsThePlayingEstimate();
    void stalledAndRegressingPollsYieldToHealthyForwardPosition();
    void playingPositionEstimateClampsToDuration();
    void explicitZeroSeekedIsAccepted();
    void pausedZeroPositionIsAccepted();
    void initialPlayingZeroPositionIsAccepted();
    void metadataIdentityChangeAllowsPlayingZeroPosition();
    void metadataIdentityChangeRejectsPriorTrackPositionReply();
    void delayedMetadataCannotClearNewerSeekedPreservation();
    void failedPlayingSeekRollsBackToZero();
    void failedPlayingSeekRollbackSurvivesNewerZeroPoll();
    void pausedSetPositionUpdatesImmediatelyAndReconcilesSuccess();
    void pausedSetPositionErrorRollsBackWithoutPolling();
    void pausedRelativeSeekUpdatesImmediatelyAndRejectsStalePosition();
    void playerctldMirrorCannotDisplaceOrResetRealPlayer();
    void playerctldRemainsAvailableForSoleAndManualSelection();
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

    const QStringList proxyAndReal{
        QStringLiteral("playerctld"), QStringLiteral("firefox.instance1")};
    QCOMPARE(MprisManager::resolvePreferredPlayer(proxyAndReal, QStringLiteral("playerctld")),
             QStringLiteral("playerctld"));
    QCOMPARE(MprisManager::resolvePreferredPlayer({QStringLiteral("playerctld")}, QString()),
             QStringLiteral("playerctld"));
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

    const QStringList proxyAndReal{
        QStringLiteral("firefox.instance1"), QStringLiteral("playerctld")};
    const QMap<QString, QString> transientProxyPlaying{
        {QStringLiteral("firefox.instance1"), QStringLiteral("Paused")},
        {QStringLiteral("playerctld"), QStringLiteral("Playing")},
    };
    QCOMPARE(MprisManager::resolveAutoPlayer(
                 proxyAndReal, transientProxyPlaying, QStringLiteral("firefox.instance1")),
             QStringLiteral("firefox.instance1"));
    QCOMPARE(MprisManager::resolveAutoPlayer(
                 proxyAndReal, transientProxyPlaying, QStringLiteral("playerctld")),
             QStringLiteral("firefox.instance1"));
    QCOMPARE(MprisManager::resolveAutoPlayer(
                 {QStringLiteral("playerctld")},
                 {{QStringLiteral("playerctld"), QStringLiteral("Playing")}}, QString()),
             QStringLiteral("playerctld"));
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

void ServiceSettingsTests::selectedSeekedIsAppliedAndUnselectedSeekedIsIgnored()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString selectedName = QStringLiteral("ciderdeck_test_seeked_a_") + suffix;
    const QString otherName = QStringLiteral("ciderdeck_test_seeked_b_") + suffix;
    FakeMprisService selected(selectedName, QStringLiteral("seeked-a-") + suffix);
    FakeMprisService other(otherName, QStringLiteral("seeked-b-") + suffix);
    MprisManager manager;
    QTRY_VERIFY_WITH_TIMEOUT(manager.playerNames().contains(otherName), 2000);
    manager.selectPreferredPlayer(selectedName);
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), selectedName, 2000);

    selected.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    other.emitSeeked(99000000LL);
    QTest::qWait(50);
    QCOMPARE(manager.position(), 42000000LL);

    manager.selectPreferredPlayer(otherName);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 99000000LL, 2000);
    selected.emitSeeked(77000000LL);
    QTest::qWait(50);
    QCOMPARE(manager.position(), 99000000LL);
}

void ServiceSettingsTests::playingZeroPollsDoNotOverrideAuthoritativeSeeked()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_zero_poll_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("zero-poll-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 180000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.duration(), 180000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);

    QVariantMap incompleteMetadata = service.player.metadata_;
    incompleteMetadata.remove(QStringLiteral("mpris:length"));
    service.changeMetadata(incompleteMetadata);
    QTRY_COMPARE_WITH_TIMEOUT(manager.duration(), 180000000LL, 2000);

    const int requestsBeforeZero = service.player.positionRequestCount_;
    service.player.position_ = 0;
    QTRY_VERIFY_WITH_TIMEOUT(service.player.positionRequestCount_ >= requestsBeforeZero + 2, 2000);
    QVERIFY(manager.position() >= 42000000LL);
}

void ServiceSettingsTests::stalledPlayingPositionAdvancesMonotonically()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_stalled_position_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("stalled-position-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 180000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTest::qWait(1150);

    QVERIFY2(manager.position() >= 10800000LL,
             qPrintable(QStringLiteral("stalled Playing position remained at %1")
                            .arg(manager.position())));
    QVERIFY(manager.position() <= 12000000LL);
}

void ServiceSettingsTests::playingPositionEstimateSaturatesAtSignedMaximum()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_estimate_limit_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("estimate-limit-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = std::numeric_limits<qlonglong>::max();
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(
        manager.position(), std::numeric_limits<qlonglong>::max(), 2000);
    QTest::qWait(650);

    QCOMPARE(manager.position(), std::numeric_limits<qlonglong>::max());
}

void ServiceSettingsTests::playingSkipForwardUsesAbsoluteEstimatedPosition()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_absolute_skip_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("absolute-skip-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 180000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTest::qWait(1150);
    manager.skipForward(10);

    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 1, 2000);
    QCOMPARE(service.player.methodCalls_.value(QStringLiteral("Seek")), 0);
    const QList<QVariant> arguments =
        service.player.methodArguments_.value(QStringLiteral("SetPosition"));
    QCOMPARE(arguments.size(), 2);
    QCOMPARE(qvariant_cast<QDBusObjectPath>(arguments.at(0)).path(),
             QStringLiteral("/test/track"));
    const qlonglong target = arguments.at(1).toLongLong();
    QVERIFY2(target >= 20800000LL && target <= 22500000LL,
             qPrintable(QStringLiteral("absolute +10 target was %1").arg(target)));
}

void ServiceSettingsTests::playingSkipBackwardUsesAbsoluteEstimatedPosition()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_absolute_back_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("absolute-back-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 30000000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 180000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 30000000LL, 2000);
    QTest::qWait(1150);
    manager.skipBackward(10);

    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 1, 2000);
    QCOMPARE(service.player.methodCalls_.value(QStringLiteral("Seek")), 0);
    const QList<QVariant> arguments =
        service.player.methodArguments_.value(QStringLiteral("SetPosition"));
    QCOMPARE(arguments.size(), 2);
    QCOMPARE(qvariant_cast<QDBusObjectPath>(arguments.at(0)).path(),
             QStringLiteral("/test/track"));
    const qlonglong target = arguments.at(1).toLongLong();
    QVERIFY2(target >= 20800000LL && target <= 22500000LL,
             qPrintable(QStringLiteral("absolute -10 target was %1").arg(target)));
}

void ServiceSettingsTests::absoluteSkipTargetsClampToTrackBounds()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_skip_bounds_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("skip-bounds-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 9500000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 10000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 9500000LL, 2000);
    manager.skipForward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 1, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition")).value(1).toLongLong(),
             10000000LL);

    service.emitSeeked(5000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 5000000LL, 2000);
    manager.skipBackward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 2, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition")).value(1).toLongLong(),
             0LL);
}

void ServiceSettingsTests::absoluteSkipTargetsSaturateAtSignedLimits()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_skip_limits_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("skip-limits-") + suffix);
    service.player.position_ = std::numeric_limits<qlonglong>::max() - 5;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(
        manager.position(), std::numeric_limits<qlonglong>::max() - 5, 2000);
    manager.skipForward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 1, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition"))
                 .value(1).toLongLong(),
             std::numeric_limits<qlonglong>::max());

    service.emitSeeked(std::numeric_limits<qlonglong>::max() - 5);
    QTRY_COMPARE_WITH_TIMEOUT(
        manager.position(), std::numeric_limits<qlonglong>::max() - 5, 2000);
    manager.skipBackward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 2, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition"))
                 .value(1).toLongLong(),
             std::numeric_limits<qlonglong>::max() - 10000005LL);

    service.emitSeeked(std::numeric_limits<qlonglong>::min() + 5);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
    manager.skipForward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 3, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition"))
                 .value(1).toLongLong(),
             10000000LL);

    service.emitSeeked(std::numeric_limits<qlonglong>::min() + 5);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
    manager.skipBackward(10);
    QTRY_COMPARE_WITH_TIMEOUT(
        service.player.methodCalls_.value(QStringLiteral("SetPosition")), 4, 2000);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("SetPosition"))
                 .value(1).toLongLong(),
             0LL);
}

void ServiceSettingsTests::invalidTrackIdFallsBackToRelativeSkip()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_skip_fallback_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("skip-fallback-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 30000000LL;
    service.player.metadata_[QStringLiteral("mpris:trackid")] = QStringLiteral("/test/träck");
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 30000000LL, 2000);
    manager.skipForward(10);

    QTRY_COMPARE_WITH_TIMEOUT(service.player.methodCalls_.value(QStringLiteral("Seek")), 1, 2000);
    QCOMPARE(service.player.methodCalls_.value(QStringLiteral("SetPosition")), 0);
    QCOMPARE(service.player.methodArguments_.value(QStringLiteral("Seek")).value(0).toLongLong(),
             10000000LL);
}

void ServiceSettingsTests::relativeSeekOptimismSaturatesAtSignedLimits()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_seek_limits_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("seek-limits-") + suffix);
    service.player.metadata_[QStringLiteral("mpris:trackid")] = QStringLiteral("invalid");
    service.player.position_ = std::numeric_limits<qlonglong>::max() - 5;
    service.player.errorMethods_.insert(QStringLiteral("Seek"));
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(
        manager.position(), std::numeric_limits<qlonglong>::max() - 5, 2000);
    manager.seek(10000000LL);
    QCOMPARE(manager.position(), std::numeric_limits<qlonglong>::max());
    QTRY_COMPARE_WITH_TIMEOUT(service.player.methodCalls_.value(QStringLiteral("Seek")), 1, 2000);

    service.emitSeeked(std::numeric_limits<qlonglong>::min() + 5);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
    manager.seek(std::numeric_limits<qlonglong>::min());
    QCOMPARE(manager.position(), 0LL);
    QTRY_COMPARE_WITH_TIMEOUT(service.player.methodCalls_.value(QStringLiteral("Seek")), 2, 2000);
}

void ServiceSettingsTests::stoppedPositionIsReconciledAndStopsAdvancing()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_stopped_position_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("stopped-position-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTest::qWait(650);
    service.player.position_ = 0;
    service.changePlaybackStatus(QStringLiteral("Stopped"));

    QTRY_COMPARE_WITH_TIMEOUT(manager.playbackStatus(), QStringLiteral("Stopped"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
    QTest::qWait(1100);
    QCOMPARE(manager.position(), 0LL);
}

void ServiceSettingsTests::trackChangeStopsThePriorPositionEstimate()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_track_reset_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("track-reset-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 42000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.player.delayPosition_ = true;
    service.changeMetadata({
        {QStringLiteral("mpris:trackid"),
         QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/replacement_track")))},
        {QStringLiteral("xesam:title"), QStringLiteral("Replacement track")},
    });

    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Replacement track"), 2000);
    QCOMPARE(manager.position(), 0LL);
    QTest::qWait(650);
    QCOMPARE(manager.position(), 0LL);
    service.player.delayPosition_ = false;
    while (!service.player.delayedPositionRequests_.isEmpty())
        service.releaseNextPositionReply();
}

void ServiceSettingsTests::backwardSeekedReanchorsThePlayingEstimate()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_seeked_reanchor_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("seeked-reanchor-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 42000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    QTest::qWait(650);
    QVERIFY(manager.position() > 42000000LL);

    service.emitSeeked(5000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 5000000LL, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(manager.position() >= 5800000LL, 2000);
    QVERIFY(manager.position() <= 7000000LL);
}

void ServiceSettingsTests::stalledAndRegressingPollsYieldToHealthyForwardPosition()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_position_order_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("position-order-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTest::qWait(650);
    const qlonglong afterStall = manager.position();
    QVERIFY(afterStall > 10000000LL);

    service.player.position_ = 9000000LL;
    QTest::qWait(650);
    QVERIFY(manager.position() > afterStall);

    service.player.position_ = 30000000LL;
    QTRY_VERIFY_WITH_TIMEOUT(manager.position() >= 30000000LL, 2000);
    QVERIFY(manager.position() <= 31500000LL);
}

void ServiceSettingsTests::playingPositionEstimateClampsToDuration()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_position_clamp_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("position-clamp-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 9500000LL;
    service.player.metadata_[QStringLiteral("mpris:length")] = 10000000LL;
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 9500000LL, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTest::qWait(650);
    QCOMPARE(manager.position(), 10000000LL);
}

void ServiceSettingsTests::explicitZeroSeekedIsAccepted()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_zero_seeked_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("zero-seeked-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.emitSeeked(0);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
}

void ServiceSettingsTests::pausedZeroPositionIsAccepted()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_paused_zero_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("paused-zero-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.player.position_ = 0;
    service.changePlaybackStatus(QStringLiteral("Paused"));
    QTRY_COMPARE_WITH_TIMEOUT(manager.playbackStatus(), QStringLiteral("Paused"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
}

void ServiceSettingsTests::initialPlayingZeroPositionIsAccepted()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_initial_zero_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("initial-zero-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    MprisManager manager;

    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), playerName, 2000);
    QTRY_VERIFY_WITH_TIMEOUT(service.player.positionRequestCount_ >= 2, 2000);
    QVERIFY(manager.position() > 0LL);
}

void ServiceSettingsTests::metadataIdentityChangeAllowsPlayingZeroPosition()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_track_zero_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("track-zero-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.player.position_ = 0;
    service.changeMetadata({
        {QStringLiteral("mpris:trackid"),
         QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/next_track")))},
        {QStringLiteral("xesam:title"), QStringLiteral("Next track")},
    });
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Next track"), 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
}

void ServiceSettingsTests::metadataIdentityChangeRejectsPriorTrackPositionReply()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_track_position_race_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("track-position-race-") + suffix);
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.player.delayPosition_ = true;
    service.player.position_ = 12000000LL;
    service.changePlaybackStatus(QStringLiteral("Paused"));
    QTRY_COMPARE_WITH_TIMEOUT(service.player.delayedPositionRequests_.size(), 1, 2000);

    service.changeMetadata({
        {QStringLiteral("mpris:trackid"),
         QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/next_race_track")))},
        {QStringLiteral("xesam:title"), QStringLiteral("Next race track")},
    });
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Next race track"), 2000);
    service.releaseNextPositionReply();
    QTest::qWait(50);
    QCOMPARE(manager.position(), 0LL);
}

void ServiceSettingsTests::delayedMetadataCannotClearNewerSeekedPreservation()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_metadata_seeked_race_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("metadata-seeked-race-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Fake track"), 2000);

    service.player.delayMetadata_ = true;
    service.changeMetadata({
        {QStringLiteral("mpris:trackid"),
         QVariant::fromValue(QDBusObjectPath(QStringLiteral("/test/delayed_track")))},
        {QStringLiteral("xesam:title"), QStringLiteral("Delayed track")},
    });
    QTRY_COMPARE_WITH_TIMEOUT(service.player.delayedMetadataRequests_.size(), 1, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    const int requestsBeforeZero = service.player.positionRequestCount_;
    service.player.position_ = 0;
    service.releaseNextMetadataReply();
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Delayed track"), 2000);
    QTRY_VERIFY_WITH_TIMEOUT(service.player.positionRequestCount_ >= requestsBeforeZero + 2, 2000);
    QVERIFY(manager.position() >= 42000000LL);
}

void ServiceSettingsTests::failedPlayingSeekRollsBackToZero()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_failed_zero_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("failed-zero-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    service.player.errorMethods_.insert(QStringLiteral("SetPosition"));
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.player.position_ = 0;
    const int requestsBefore = service.player.positionRequestCount_;
    manager.setPosition(30000000LL);
    QCOMPARE(manager.position(), 30000000LL);
    QTRY_VERIFY_WITH_TIMEOUT(service.player.positionRequestCount_ > requestsBefore, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
}

void ServiceSettingsTests::failedPlayingSeekRollbackSurvivesNewerZeroPoll()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_failed_reordered_zero_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("failed-reordered-zero-") + suffix);
    service.player.playbackStatus_ = QStringLiteral("Playing");
    service.player.position_ = 10000000LL;
    service.player.errorMethods_.insert(QStringLiteral("SetPosition"));
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.emitSeeked(42000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 42000000LL, 2000);
    service.player.delayPosition_ = true;
    service.player.position_ = 0;
    manager.setPosition(30000000LL);
    QCOMPARE(manager.position(), 30000000LL);
    QTRY_VERIFY_WITH_TIMEOUT(service.player.delayedPositionRequests_.size() >= 2, 2000);

    service.releaseNextPositionReply();
    service.releaseNextPositionReply();
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 0LL, 2000);
}

void ServiceSettingsTests::pausedSetPositionUpdatesImmediatelyAndReconcilesSuccess()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_set_success_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("set-success-") + suffix);
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    const int requestsBefore = service.player.positionRequestCount_;
    manager.setPosition(25000000LL);
    QCOMPARE(manager.position(), 25000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(service.player.positionRequestCount_, requestsBefore + 1, 2000);
    QCOMPARE(manager.position(), 25000000LL);
}

void ServiceSettingsTests::pausedSetPositionErrorRollsBackWithoutPolling()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_set_error_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("set-error-") + suffix);
    service.player.position_ = 12000000LL;
    service.player.errorMethods_.insert(QStringLiteral("SetPosition"));
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 12000000LL, 2000);

    const int requestsBefore = service.player.positionRequestCount_;
    manager.setPosition(30000000LL);
    QCOMPARE(manager.position(), 30000000LL);
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 12000000LL, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(service.player.positionRequestCount_, requestsBefore + 1, 2000);
    QTest::qWait(1100);
    QCOMPARE(service.player.positionRequestCount_, requestsBefore + 1);
}

void ServiceSettingsTests::pausedRelativeSeekUpdatesImmediatelyAndRejectsStalePosition()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString playerName = QStringLiteral("ciderdeck_test_relative_seek_") + suffix;
    FakeMprisService service(playerName, QStringLiteral("relative-seek-") + suffix);
    service.player.position_ = 10000000LL;
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 10000000LL, 2000);

    service.player.delayPosition_ = true;
    service.changePlaybackStatus(QStringLiteral("Playing"));
    service.changePlaybackStatus(QStringLiteral("Paused"));
    QTRY_VERIFY_WITH_TIMEOUT(!service.player.delayedPositionRequests_.isEmpty(), 2000);
    manager.seek(5000000LL);
    QVERIFY(manager.position() >= 15000000LL);
    service.releaseNextPositionReply();
    QTest::qWait(50);
    QVERIFY(manager.position() >= 15000000LL);

    service.player.delayPosition_ = false;
    while (!service.player.delayedPositionRequests_.isEmpty())
        service.releaseNextPositionReply();
    QTRY_COMPARE_WITH_TIMEOUT(manager.position(), 15000000LL, 2000);
}

void ServiceSettingsTests::playerctldMirrorCannotDisplaceOrResetRealPlayer()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    const QString realName = QStringLiteral("ciderdeck_test_real_") + suffix;
    FakeMprisService real(realName, QStringLiteral("mirror-real-") + suffix);
    FakeMprisService proxy(QStringLiteral("playerctld"), QStringLiteral("mirror-proxy-") + suffix);
    MprisManager manager;
    QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), realName, 2000);
    QTRY_COMPARE_WITH_TIMEOUT(manager.title(), QStringLiteral("Fake track"), 2000);
    QSignalSpy playerSpy(&manager, &MprisManager::currentPlayerChanged);
    QSignalSpy metadataSpy(&manager, &MprisManager::metadataChanged);

    proxy.changePlaybackStatus(QStringLiteral("Playing"));
    QTest::qWait(100);
    QCOMPARE(manager.currentPlayer(), realName);
    QCOMPARE(manager.title(), QStringLiteral("Fake track"));
    QCOMPARE(playerSpy.count(), 0);
    QCOMPARE(metadataSpy.count(), 0);
}

void ServiceSettingsTests::playerctldRemainsAvailableForSoleAndManualSelection()
{
    const QString suffix = QString::number(QCoreApplication::applicationPid());
    {
        FakeMprisService proxy(QStringLiteral("playerctld"), QStringLiteral("sole-proxy-") + suffix);
        MprisManager manager;
        QTRY_COMPARE_WITH_TIMEOUT(manager.currentPlayer(), QStringLiteral("playerctld"), 2000);
    }

    const QString realName = QStringLiteral("ciderdeck_test_manual_real_") + suffix;
    FakeMprisService real(realName, QStringLiteral("manual-real-") + suffix);
    FakeMprisService proxy(QStringLiteral("playerctld"), QStringLiteral("manual-proxy-") + suffix);
    MprisManager manager;
    QTRY_VERIFY_WITH_TIMEOUT(manager.playerNames().contains(QStringLiteral("playerctld")), 2000);
    manager.selectPreferredPlayer(QStringLiteral("playerctld"));
    QCOMPARE(manager.currentPlayer(), QStringLiteral("playerctld"));
    real.changePlaybackStatus(QStringLiteral("Playing"));
    QTest::qWait(100);
    QCOMPARE(manager.currentPlayer(), QStringLiteral("playerctld"));
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
