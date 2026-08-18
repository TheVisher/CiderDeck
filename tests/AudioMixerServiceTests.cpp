#include <QTest>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "services/AudioManager.h"
#include "services/AudioMixerService.h"
#include "services/AudioRoutingPolicy.h"

#include <memory>

using namespace ciderdeck;

class AudioMixerServiceTests : public QObject {
    Q_OBJECT

private slots:
    void init();
    void cleanup();
    void stableSinkNameResolvesRecreatedDeviceIndex();
    void internalProcessingStreamsAreNeverRouted();
    void reclassifiedAppMovesFromGeneralToAssignedDestination();
    void unavailableAssignmentIsRetainedWithoutRouting();
    void existingTargetDoesNotRequestMove();
    void appReassignmentChangesDestination();
    void legacyConfigLoadsWithoutOutputAssignment();
    void outputAssignmentPersistsStableSinkName();
    void clearingOutputAssignmentRestoresVolumeOnlyConfig();
    void optionalIntegrationFallbackHasNoDestinations();
    void unchangedGroupAssignmentsDoNotEmitChanges();

private:
    std::unique_ptr<QTemporaryDir> configDir_;
    QByteArray originalPath_;
};

void AudioMixerServiceTests::init()
{
    configDir_ = std::make_unique<QTemporaryDir>();
    QVERIFY(configDir_->isValid());
    qputenv("CIDERDECK_CONFIG_DIR", configDir_->path().toUtf8());
    originalPath_ = qgetenv("PATH");

    const QString binDir = configDir_->filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDir));
    QFile fakeWhich(binDir + QStringLiteral("/which"));
    QVERIFY(fakeWhich.open(QIODevice::WriteOnly));
    fakeWhich.write("#!/bin/sh\nexit 1\n");
    fakeWhich.close();
    QVERIFY(fakeWhich.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                     | QFileDevice::ExeOwner));
    qputenv("PATH", binDir.toUtf8());
}

void AudioMixerServiceTests::cleanup()
{
    qunsetenv("CIDERDECK_CONFIG_DIR");
    qputenv("PATH", originalPath_);
    configDir_.reset();
}

void AudioMixerServiceTests::stableSinkNameResolvesRecreatedDeviceIndex()
{
    const QList<audio::RoutingGroup> groups{
        {QStringList{QStringLiteral("Zen")}, QStringLiteral("alsa_output.usb-headset"), false},
    };
    const audio::RoutingStream stream{
        QStringLiteral("Zen"),
        QStringLiteral("Playback Stream"),
        8,
    };

    const auto initialTarget = audio::routeTargetDeviceIndex(
        stream,
        groups,
        {{QStringLiteral("alsa_output.usb-headset"), QStringLiteral("USB Headset"), 31}});
    QVERIFY(initialTarget.has_value());
    QCOMPARE(initialTarget.value(), 31U);

    const auto recreatedTarget = audio::routeTargetDeviceIndex(
        stream,
        groups,
        {{QStringLiteral("alsa_output.usb-headset"), QStringLiteral("USB Headset"), 77}});
    QVERIFY(recreatedTarget.has_value());
    QCOMPARE(recreatedTarget.value(), 77U);
}

void AudioMixerServiceTests::internalProcessingStreamsAreNeverRouted()
{
    const QList<audio::RoutingGroup> groups{
        {QStringList{QStringLiteral("Sonar Gaming output"), QStringLiteral("Zen")},
         QStringLiteral("alsa_output.usb-headset"),
         false},
    };
    const QList<audio::RoutingSink> sinks{
        {QStringLiteral("alsa_output.usb-headset"), QStringLiteral("USB Headset"), 31},
    };

    QVERIFY(!audio::routeTargetDeviceIndex(
                 {QStringLiteral("Sonar Gaming output"), QStringLiteral("Playback Stream"), 8},
                 groups,
                 sinks)
                 .has_value());
    QVERIFY(!audio::routeTargetDeviceIndex(
                 {QStringLiteral("Zen"), QStringLiteral("effect_output.sonar-game"), 8},
                 groups,
                 sinks)
                 .has_value());
}

void AudioMixerServiceTests::reclassifiedAppMovesFromGeneralToAssignedDestination()
{
    const QList<audio::RoutingGroup> groups{
        {QStringList{}, QStringLiteral("system.output"), true},
        {QStringList{QStringLiteral("Zen")}, QStringLiteral("media.output"), false},
    };
    const QList<audio::RoutingSink> sinks{
        {QStringLiteral("system.output"), QStringLiteral("System Output"), 10},
        {QStringLiteral("media.output"), QStringLiteral("Media Output"), 20},
    };

    const auto unidentifiedTarget = audio::routeTargetDeviceIndex(
        {QStringLiteral("AudioStream"), QStringLiteral("Playback Stream"), 1},
        groups,
        sinks);
    QVERIFY(unidentifiedTarget.has_value());
    QCOMPARE(unidentifiedTarget.value(), 10U);

    const auto identifiedTarget = audio::routeTargetDeviceIndex(
        {QStringLiteral("Zen"), QStringLiteral("Playback Stream"), 10},
        groups,
        sinks);
    QVERIFY(identifiedTarget.has_value());
    QCOMPARE(identifiedTarget.value(), 20U);
}

void AudioMixerServiceTests::unavailableAssignmentIsRetainedWithoutRouting()
{
    const auto decision = audio::routingDecision(
        {QStringLiteral("Zen"), QStringLiteral("Playback Stream"), 8},
        {{QStringList{QStringLiteral("Zen")}, QStringLiteral("media.output"), false}},
        {});

    QCOMPARE(decision.status, audio::RoutingStatus::DestinationUnavailable);
    QVERIFY(!decision.targetDeviceIndex.has_value());
}

void AudioMixerServiceTests::existingTargetDoesNotRequestMove()
{
    const auto decision = audio::routingDecision(
        {QStringLiteral("Zen"), QStringLiteral("Playback Stream"), 20},
        {{QStringList{QStringLiteral("Zen")}, QStringLiteral("media.output"), false}},
        {{QStringLiteral("media.output"), QStringLiteral("Media Output"), 20}});

    QCOMPARE(decision.status, audio::RoutingStatus::AlreadyRouted);
    QVERIFY(!decision.targetDeviceIndex.has_value());
}

void AudioMixerServiceTests::appReassignmentChangesDestination()
{
    const QList<audio::RoutingSink> sinks{
        {QStringLiteral("media.output"), QStringLiteral("Media Output"), 20},
        {QStringLiteral("game.output"), QStringLiteral("Game Output"), 30},
    };
    const audio::RoutingStream stream{
        QStringLiteral("Zen"), QStringLiteral("Playback Stream"), 20};

    const auto reassignedTarget = audio::routeTargetDeviceIndex(
        stream,
        {
            {QStringList{}, QStringLiteral("media.output"), false},
            {QStringList{QStringLiteral("Zen")}, QStringLiteral("game.output"), false},
        },
        sinks);

    QVERIFY(reassignedTarget.has_value());
    QCOMPARE(reassignedTarget.value(), 30U);
}

void AudioMixerServiceTests::legacyConfigLoadsWithoutOutputAssignment()
{
    QFile config(configDir_->filePath(QStringLiteral("mixer.json")));
    QVERIFY(config.open(QIODevice::WriteOnly));
    config.write(R"json([
        {
            "name": "Media",
            "volume": 82,
            "muted": false,
            "isGeneral": false,
            "apps": ["Zen"]
        }
    ])json");
    config.close();

    AudioManager audioManager;
    AudioMixerService service(&audioManager);
    const QVariantMap group = service.groups().constFirst().toMap();

    QCOMPARE(group.value(QStringLiteral("outputSinkName")).toString(), QString());
    QCOMPARE(group.value(QStringLiteral("outputAvailable")).toBool(), true);
    QCOMPARE(group.value(QStringLiteral("volume")).toInt(), 82);
}

void AudioMixerServiceTests::outputAssignmentPersistsStableSinkName()
{
    {
        AudioManager audioManager;
        AudioMixerService service(&audioManager);
        service.setGroupOutput(1, QStringLiteral("alsa_output.usb-headset"));
    }

    QFile config(configDir_->filePath(QStringLiteral("mixer.json")));
    QVERIFY(config.open(QIODevice::ReadOnly));
    const QJsonArray savedGroups = QJsonDocument::fromJson(config.readAll()).array();
    QCOMPARE(savedGroups.at(1).toObject().value(QStringLiteral("outputSinkName")).toString(),
             QStringLiteral("alsa_output.usb-headset"));

    AudioManager audioManager;
    AudioMixerService reloaded(&audioManager);
    const QVariantMap group = reloaded.groups().at(1).toMap();
    QCOMPARE(group.value(QStringLiteral("outputSinkName")).toString(),
             QStringLiteral("alsa_output.usb-headset"));
    QCOMPARE(group.value(QStringLiteral("outputAvailable")).toBool(), false);
}

void AudioMixerServiceTests::clearingOutputAssignmentRestoresVolumeOnlyConfig()
{
    AudioManager audioManager;
    AudioMixerService service(&audioManager);
    service.setGroupOutput(2, QStringLiteral("media.output"));
    service.setGroupOutput(2, QString());

    const QVariantMap group = service.groups().at(2).toMap();
    QCOMPARE(group.value(QStringLiteral("outputSinkName")).toString(), QString());
    QCOMPARE(group.value(QStringLiteral("outputAvailable")).toBool(), true);

    QFile config(configDir_->filePath(QStringLiteral("mixer.json")));
    QVERIFY(config.open(QIODevice::ReadOnly));
    const QJsonArray savedGroups = QJsonDocument::fromJson(config.readAll()).array();
    QVERIFY(!savedGroups.at(2).toObject().contains(QStringLiteral("outputSinkName")));
}

void AudioMixerServiceTests::optionalIntegrationFallbackHasNoDestinations()
{
    AudioManager audioManager;
    AudioMixerService service(&audioManager);
    service.setGroupOutput(3, QStringLiteral("chat.output"));

    QVERIFY(service.outputDestinations().isEmpty());
    const QVariantMap group = service.groups().at(3).toMap();
    QCOMPARE(group.value(QStringLiteral("outputSinkName")).toString(),
             QStringLiteral("chat.output"));
    QCOMPARE(group.value(QStringLiteral("outputAvailable")).toBool(), false);
}

void AudioMixerServiceTests::unchangedGroupAssignmentsDoNotEmitChanges()
{
    AudioManager audioManager;
    AudioMixerService service(&audioManager);
    QSignalSpy groupsChanged(&service, &AudioMixerService::groupsChanged);

    service.setGroupOutput(1, QStringLiteral("game.output"));
    groupsChanged.clear();
    service.setGroupOutput(1, QStringLiteral("game.output"));
    QCOMPARE(groupsChanged.count(), 0);

    service.removeAppFromGroup(1, QStringLiteral("Zen"));
    QCOMPARE(groupsChanged.count(), 0);

    service.addAppToGroup(2, QStringLiteral("Zen"));
    groupsChanged.clear();
    service.addAppToGroup(2, QStringLiteral("Zen"));
    QCOMPARE(groupsChanged.count(), 0);

    service.moveAppToGroup(QStringLiteral("Zen"), 2);
    QCOMPARE(groupsChanged.count(), 0);
}

QTEST_GUILESS_MAIN(AudioMixerServiceTests)

#include "AudioMixerServiceTests.moc"
