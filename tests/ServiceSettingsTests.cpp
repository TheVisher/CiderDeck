#include <QTest>

#include "services/MprisManager.h"
#include "services/TimerService.h"

using namespace ciderdeck;

class ServiceSettingsTests : public QObject {
    Q_OBJECT

private slots:
    void timerDefaultDurationIsApplied();
    void preferredMediaPlayerIsResolved();
    void mediaDurationSurvivesIncompleteMetadataRefresh();
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

QTEST_GUILESS_MAIN(ServiceSettingsTests)

#include "ServiceSettingsTests.moc"
