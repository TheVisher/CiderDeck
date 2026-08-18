#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>

#include <cerrno>
#include <unistd.h>
#include <linux/input.h>

#include "services/EvdevTouchService.h"

namespace ciderdeck {

class EvdevTouchServiceTests : public QObject {
    Q_OBJECT

private slots:
    void enumeratesAllEventNodes();
    void discoversOncePerCycleDuringRepeatedAbsence();
    void recoversFromAReenumeratedDevicePath();
    void boundsReconnectBackoff();
    void suppressesRepeatedUnavailableLogs();
    void recoveryResetsRetryState();
    void manualStopBlocksStaleReconnectCallback();
    void manualStopSurvivesSystemWake();
    void manualStopBlocksRetryScheduling();
    void explicitStartReenablesRetriesAfterManualStop();
    void reportsPermissionDeniedDuringAutoDetection();
    void classifiesPermissionOpenErrors_data();
    void classifiesPermissionOpenErrors();
    void reentrantStopCancelsInFlightReconnect();
    void reentrantStartSupersedesInFlightReconnect();
    void prefersDirectMultitouchOverRelativeDuplicate();
    void selectionDoesNotDependOnEventNumber();
    void stableIdentityRejectsAPathReusedByAnotherDevice();
    void rediscoveryUsesStableIdentityInsteadOfRememberedPath();
    void modernMultitouchProducesPressMoveAndRelease();
    void legacyAbsoluteTouchStillProducesInput();
    void multitouchHandsOffAfterPrimaryContactEnds();
    void synDroppedReleasesAndDiscardsStaleEvents();
    void rejectsDirectAbsoluteDeviceWithoutTouchSignal();
    void rejectsIndirectTouchpadDuringAutomaticSelection();
    void cancellingInputReleasesAnActivePress();
    void mapsPressMoveReleaseAndCancellationThroughCalibration();
    void loadsCalibrationProfileForSelectedStableIdentity();
    void emitsUncalibratedRawCoordinatesForCalibration();
    void exposesCalibrationDeviceStateAndPersistence();
    void calibrationPathHonorsIsolatedConfigDirectory();
};

void EvdevTouchServiceTests::enumeratesAllEventNodes()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    for (const QString &name : {QStringLiteral("event2"),
                                QStringLiteral("event9"),
                                QStringLiteral("event10"),
                                QStringLiteral("event42"),
                                QStringLiteral("event-not-a-node"),
                                QStringLiteral("mouse0")}) {
        QFile node(inputDirectory.filePath(name));
        QVERIFY(node.open(QIODevice::WriteOnly));
    }

    const QStringList expected{
        inputDirectory.filePath(QStringLiteral("event2")),
        inputDirectory.filePath(QStringLiteral("event9")),
        inputDirectory.filePath(QStringLiteral("event10")),
        inputDirectory.filePath(QStringLiteral("event42")),
    };
    QCOMPARE(EvdevTouchService::eventDevicePaths(inputDirectory.path()), expected);
}

void EvdevTouchServiceTests::discoversOncePerCycleDuringRepeatedAbsence()
{
    int discoveryCount = 0;
    int openCount = 0;

    for (int cycle = 0; cycle < 10; ++cycle) {
        const QString recoveredPath = EvdevTouchService::attemptReconnectCycle(
            {},
            [&discoveryCount]() {
                ++discoveryCount;
                return QString{};
            },
            [&openCount](const QString &) {
                ++openCount;
                return false;
            });
        QVERIFY(recoveredPath.isEmpty());
    }

    QCOMPARE(discoveryCount, 10);
    QCOMPARE(openCount, 0);
}

void EvdevTouchServiceTests::recoversFromAReenumeratedDevicePath()
{
    int discoveryCount = 0;
    QStringList attemptedPaths;

    const QString recoveredPath = EvdevTouchService::attemptReconnectCycle(
        QStringLiteral("/dev/input/event9"),
        [&discoveryCount]() {
            ++discoveryCount;
            return QStringLiteral("/dev/input/event42");
        },
        [&attemptedPaths](const QString &path) {
            attemptedPaths.append(path);
            return path == QStringLiteral("/dev/input/event42");
        });

    QCOMPARE(recoveredPath, QStringLiteral("/dev/input/event42"));
    QCOMPARE(discoveryCount, 1);
    QCOMPARE(attemptedPaths, QStringList({QStringLiteral("/dev/input/event42")}));
}

void EvdevTouchServiceTests::boundsReconnectBackoff()
{
    EvdevTouchService::RetryState retryState;
    const QList<int> expectedDelays{3000, 6000, 12000, 24000, 48000, 60000, 60000};

    QList<int> actualDelays;
    for (qsizetype i = 0; i < expectedDelays.size(); ++i)
        actualDelays.append(retryState.recordFailure());

    QCOMPARE(actualDelays, expectedDelays);
}

void EvdevTouchServiceTests::suppressesRepeatedUnavailableLogs()
{
    EvdevTouchService::RetryState retryState;

    QVERIFY(retryState.shouldLogUnavailable());
    QVERIFY(!retryState.shouldLogUnavailable());
    QVERIFY(!retryState.shouldLogUnavailable());
}

void EvdevTouchServiceTests::recoveryResetsRetryState()
{
    EvdevTouchService::RetryState retryState;
    retryState.shouldLogUnavailable();
    QCOMPARE(retryState.recordFailure(), 3000);
    QCOMPARE(retryState.recordFailure(), 6000);

    QVERIFY(retryState.markRecovered());
    QVERIFY(!retryState.markRecovered());
    QCOMPARE(retryState.recordFailure(), 3000);
    QVERIFY(retryState.shouldLogUnavailable());
}

void EvdevTouchServiceTests::manualStopBlocksStaleReconnectCallback()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    EvdevTouchService service(nullptr);
    service.inputDirectory_ = inputDirectory.path();
    service.retryState_.unavailableLogEmitted = true;
    QVERIFY(!service.start());
    QVERIFY(service.reconnectTimer_->isActive());

    service.stop();
    QVERIFY(!service.reconnectTimer_->isActive());

    service.retryState_.unavailableLogEmitted = true;
    service.reconnect();
    QVERIFY(!service.reconnectTimer_->isActive());
}

void EvdevTouchServiceTests::manualStopSurvivesSystemWake()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    EvdevTouchService service(nullptr);
    service.inputDirectory_ = inputDirectory.path();
    service.retryState_.unavailableLogEmitted = true;
    QVERIFY(!service.start());
    QVERIFY(service.reconnectTimer_->isActive());

    service.stop();
    service.onSystemWake(false);

    QVERIFY(!service.reconnectTimer_->isActive());
}

void EvdevTouchServiceTests::manualStopBlocksRetryScheduling()
{
    EvdevTouchService service(nullptr);
    service.stop();

    service.scheduleReconnect(1000);

    QVERIFY(!service.reconnectTimer_->isActive());
}

void EvdevTouchServiceTests::explicitStartReenablesRetriesAfterManualStop()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    EvdevTouchService service(nullptr);
    service.inputDirectory_ = inputDirectory.path();
    service.retryState_.unavailableLogEmitted = true;
    QVERIFY(!service.start());
    QVERIFY(service.reconnectTimer_->isActive());

    service.stop();
    QVERIFY(!service.reconnectTimer_->isActive());

    service.retryState_.unavailableLogEmitted = true;
    QVERIFY(!service.start());
    QVERIFY(service.reconnectTimer_->isActive());
}

void EvdevTouchServiceTests::reportsPermissionDeniedDuringAutoDetection()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    const QString eventPath = inputDirectory.filePath(QStringLiteral("event42"));
    QFile eventNode(eventPath);
    QVERIFY(eventNode.open(QIODevice::WriteOnly));
    eventNode.close();

    EvdevTouchService service(nullptr);
    service.inputDirectory_ = inputDirectory.path();
    service.deviceProbe_ = [](const QString &) {
        return EvdevTouchService::DeviceProbeResult::PermissionDenied;
    };
    service.retryState_.unavailableLogEmitted = true;

    QVERIFY(!service.start());
    QCOMPARE(service.lastOpenError_,
             QStringLiteral("Failed to open %1 — check permissions "
                            "(user must be in 'input' group)")
                 .arg(eventPath));
}

void EvdevTouchServiceTests::classifiesPermissionOpenErrors_data()
{
    QTest::addColumn<int>("errorNumber");
    QTest::addColumn<bool>("permissionDenied");

    QTest::newRow("EACCES") << EACCES << true;
    QTest::newRow("EPERM") << EPERM << true;
    QTest::newRow("ENOENT") << ENOENT << false;
}

void EvdevTouchServiceTests::classifiesPermissionOpenErrors()
{
    QFETCH(int, errorNumber);
    QFETCH(bool, permissionDenied);

    const auto result = EvdevTouchService::probeResultForOpenError(errorNumber);
    QCOMPARE(result == EvdevTouchService::DeviceProbeResult::PermissionDenied,
             permissionDenied);
}

void EvdevTouchServiceTests::reentrantStopCancelsInFlightReconnect()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    QFile eventNode(inputDirectory.filePath(QStringLiteral("event1")));
    QVERIFY(eventNode.open(QIODevice::WriteOnly));
    eventNode.close();

    QFile activeDevice(inputDirectory.filePath(QStringLiteral("active-device")));
    QVERIFY(activeDevice.open(QIODevice::ReadWrite));

    EvdevTouchService service(nullptr);
    service.fd_ = ::dup(activeDevice.handle());
    QVERIFY(service.fd_ >= 0);
    service.devicePath_ = activeDevice.fileName();
    service.runningRequested_ = true;
    service.inputDirectory_ = inputDirectory.path();

    int probeCount = 0;
    service.deviceProbe_ = [&probeCount](const QString &) {
        ++probeCount;
        return EvdevTouchService::DeviceProbeResult::Unavailable;
    };
    connect(&service, &EvdevTouchService::activeChanged, &service, [&service]() {
        service.stop();
        service.retryState_.unavailableLogEmitted = true;
    });

    service.reconnect();

    QCOMPARE(probeCount, 0);
    QVERIFY(!service.reconnectTimer_->isActive());
    QVERIFY(service.fd_ < 0);
}

void EvdevTouchServiceTests::reentrantStartSupersedesInFlightReconnect()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());

    QFile eventNode(inputDirectory.filePath(QStringLiteral("event1")));
    QVERIFY(eventNode.open(QIODevice::WriteOnly));
    eventNode.close();

    QFile activeDevice(inputDirectory.filePath(QStringLiteral("active-device")));
    QVERIFY(activeDevice.open(QIODevice::ReadWrite));

    EvdevTouchService service(nullptr);
    service.fd_ = ::dup(activeDevice.handle());
    QVERIFY(service.fd_ >= 0);
    service.devicePath_ = activeDevice.fileName();
    service.runningRequested_ = true;
    service.inputDirectory_ = inputDirectory.path();

    int probeCount = 0;
    int restartedFd = -1;
    bool restartSucceeded = false;
    service.deviceProbe_ = [&probeCount](const QString &) {
        ++probeCount;
        return EvdevTouchService::DeviceProbeResult::Unavailable;
    };
    const QMetaObject::Connection restartConnection = connect(
        &service, &EvdevTouchService::activeChanged, &service, [&]() {
            restartedFd = ::dup(activeDevice.handle());
            service.fd_ = restartedFd;
            service.devicePath_ = QStringLiteral("restarted");
            QTest::ignoreMessage(
                QtWarningMsg, "[EvdevTouchService] Already started on \"restarted\"");
            restartSucceeded = service.start();
        });

    service.reconnect();

    const int fdAfterReconnect = service.fd_;
    const bool retryScheduled = service.reconnectTimer_->isActive();
    QObject::disconnect(restartConnection);
    service.stop();

    QVERIFY(restartedFd >= 0);
    QVERIFY(restartSucceeded);
    QCOMPARE(probeCount, 0);
    QCOMPARE(fdAfterReconnect, restartedFd);
    QVERIFY(!retryScheduled);
}

void EvdevTouchServiceTests::prefersDirectMultitouchOverRelativeDuplicate()
{
    EvdevTouchService::DeviceCandidate relative;
    relative.path = QStringLiteral("/dev/input/event2");
    relative.identity = {0x03, 0x27c0, 0x0859, 1,
                         QStringLiteral("wch.cn TouchScreen"),
                         QStringLiteral("usb-0000:00:14.0-5/input1")};
    relative.hasRelX = true;
    relative.hasRelY = true;

    EvdevTouchService::DeviceCandidate direct = relative;
    direct.path = QStringLiteral("/dev/input/event42");
    direct.identity.physical = QStringLiteral("usb-0000:00:14.0-5/input0");
    direct.direct = true;
    direct.hasMtX = true;
    direct.hasMtY = true;
    direct.hasMtTrackingId = true;

    QCOMPARE(EvdevTouchService::selectBestCandidate({relative, direct}).path, direct.path);
    QVERIFY(EvdevTouchService::candidateScore(direct)
            > EvdevTouchService::candidateScore(relative));
}

void EvdevTouchServiceTests::selectionDoesNotDependOnEventNumber()
{
    EvdevTouchService::DeviceCandidate direct;
    direct.path = QStringLiteral("/dev/input/event1");
    direct.identity.name = QStringLiteral("wch.cn TouchScreen");
    direct.direct = true;
    direct.hasAbsX = true;
    direct.hasAbsY = true;
    direct.hasBtnTouch = true;

    EvdevTouchService::DeviceCandidate relative = direct;
    relative.path = QStringLiteral("/dev/input/event99");
    relative.direct = false;
    relative.hasAbsX = false;
    relative.hasAbsY = false;
    relative.hasBtnTouch = false;
    relative.hasRelX = true;
    relative.hasRelY = true;

    QCOMPARE(EvdevTouchService::selectBestCandidate({relative, direct}).path, direct.path);

    direct.path = QStringLiteral("/dev/input/event99");
    relative.path = QStringLiteral("/dev/input/event1");
    QCOMPARE(EvdevTouchService::selectBestCandidate({relative, direct}).path, direct.path);
}

void EvdevTouchServiceTests::stableIdentityRejectsAPathReusedByAnotherDevice()
{
    EvdevTouchService::DeviceIdentity selected{
        0x03, 0x27c0, 0x0859, 1,
        QStringLiteral("wch.cn TouchScreen"),
        QStringLiteral("usb-0000:00:14.0-5/input0")};

    EvdevTouchService::DeviceCandidate wrongDevice;
    wrongDevice.path = QStringLiteral("/dev/input/event9");
    wrongDevice.identity = selected;
    wrongDevice.identity.product = 0x9999;
    wrongDevice.direct = true;
    wrongDevice.hasMtX = true;
    wrongDevice.hasMtY = true;
    wrongDevice.hasMtTrackingId = true;

    EvdevTouchService::DeviceCandidate reenumerated = wrongDevice;
    reenumerated.path = QStringLiteral("/dev/input/event42");
    reenumerated.identity = selected;

    QCOMPARE(EvdevTouchService::selectBestCandidate({wrongDevice, reenumerated}, selected).path,
             reenumerated.path);
    QVERIFY(EvdevTouchService::selectBestCandidate({wrongDevice}, selected).path.isEmpty());
}

void EvdevTouchServiceTests::rediscoveryUsesStableIdentityInsteadOfRememberedPath()
{
    QTemporaryDir inputDirectory;
    QVERIFY(inputDirectory.isValid());
    for (const QString &name : {QStringLiteral("event9"), QStringLiteral("event42")}) {
        QFile node(inputDirectory.filePath(name));
        QVERIFY(node.open(QIODevice::WriteOnly));
    }

    EvdevTouchService service(nullptr);
    service.inputDirectory_ = inputDirectory.path();
    service.selectedIdentity_ = {0x03, 0x27c0, 0x0859, 1,
                                 QStringLiteral("wch.cn TouchScreen"),
                                 QStringLiteral("usb-port/input0")};
    service.deviceProbe_ = [&service](const QString &path) {
        EvdevTouchService::ProbedDevice probe;
        probe.result = EvdevTouchService::DeviceProbeResult::Touchscreen;
        probe.candidate.path = path;
        probe.candidate.identity = service.selectedIdentity_;
        probe.candidate.direct = true;
        probe.candidate.hasMtX = true;
        probe.candidate.hasMtY = true;
        probe.candidate.hasMtTrackingId = true;
        if (path.endsWith(QStringLiteral("event9")))
            probe.candidate.identity.product = 0x9999;
        return probe;
    };

    QCOMPARE(service.detectDevice(), inputDirectory.filePath(QStringLiteral("event42")));
}

void EvdevTouchServiceTests::modernMultitouchProducesPressMoveAndRelease()
{
    EvdevTouchService::InputState state;
    const auto feed = [&state](quint16 type, quint16 code, qint32 value) {
        return EvdevTouchService::processInputEvent(state, type, code, value);
    };

    feed(EV_ABS, ABS_MT_SLOT, 0);
    feed(EV_ABS, ABS_MT_TRACKING_ID, 7);
    feed(EV_ABS, ABS_MT_POSITION_X, 1200);
    feed(EV_ABS, ABS_MT_POSITION_Y, 800);
    auto update = feed(EV_SYN, SYN_REPORT, 0);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Press);
    QCOMPARE(update.x, 1200);
    QCOMPARE(update.y, 800);

    feed(EV_ABS, ABS_MT_POSITION_X, 1300);
    feed(EV_ABS, ABS_MT_POSITION_Y, 900);
    update = feed(EV_SYN, SYN_REPORT, 0);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Move);
    QCOMPARE(update.x, 1300);
    QCOMPARE(update.y, 900);

    feed(EV_ABS, ABS_MT_TRACKING_ID, -1);
    update = feed(EV_SYN, SYN_REPORT, 0);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Release);
    QCOMPARE(update.x, 1300);
    QCOMPARE(update.y, 900);
}

void EvdevTouchServiceTests::legacyAbsoluteTouchStillProducesInput()
{
    EvdevTouchService::InputState state;
    EvdevTouchService::processInputEvent(state, EV_ABS, ABS_X, 400);
    EvdevTouchService::processInputEvent(state, EV_ABS, ABS_Y, 300);
    EvdevTouchService::processInputEvent(state, EV_KEY, BTN_TOUCH, 1);

    auto update = EvdevTouchService::processInputEvent(state, EV_SYN, SYN_REPORT, 0);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Press);
    QCOMPARE(update.x, 400);
    QCOMPARE(update.y, 300);

    EvdevTouchService::processInputEvent(state, EV_KEY, BTN_TOUCH, 0);
    update = EvdevTouchService::processInputEvent(state, EV_SYN, SYN_REPORT, 0);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Release);
}

void EvdevTouchServiceTests::multitouchHandsOffAfterPrimaryContactEnds()
{
    EvdevTouchService::InputState state;
    const auto feed = [&state](quint16 type, quint16 code, qint32 value) {
        return EvdevTouchService::processInputEvent(state, type, code, value);
    };

    feed(EV_ABS, ABS_MT_SLOT, 0);
    feed(EV_ABS, ABS_MT_TRACKING_ID, 10);
    feed(EV_ABS, ABS_MT_POSITION_X, 100);
    feed(EV_ABS, ABS_MT_POSITION_Y, 200);
    feed(EV_ABS, ABS_MT_SLOT, 1);
    feed(EV_ABS, ABS_MT_TRACKING_ID, 11);
    feed(EV_ABS, ABS_MT_POSITION_X, 700);
    feed(EV_ABS, ABS_MT_POSITION_Y, 800);
    QCOMPARE(feed(EV_SYN, SYN_REPORT, 0).action, EvdevTouchService::TouchAction::Press);

    feed(EV_ABS, ABS_MT_SLOT, 0);
    feed(EV_ABS, ABS_MT_TRACKING_ID, -1);
    const auto handoff = feed(EV_SYN, SYN_REPORT, 0);
    QCOMPARE(handoff.action, EvdevTouchService::TouchAction::Move);
    QCOMPARE(handoff.x, 700);
    QCOMPARE(handoff.y, 800);
}

void EvdevTouchServiceTests::synDroppedReleasesAndDiscardsStaleEvents()
{
    EvdevTouchService::InputState state;
    EvdevTouchService::processInputEvent(state, EV_ABS, ABS_X, 100);
    EvdevTouchService::processInputEvent(state, EV_ABS, ABS_Y, 200);
    EvdevTouchService::processInputEvent(state, EV_KEY, BTN_TOUCH, 1);
    QCOMPARE(EvdevTouchService::processInputEvent(state, EV_SYN, SYN_REPORT, 0).action,
             EvdevTouchService::TouchAction::Press);

    const auto dropped = EvdevTouchService::processInputEvent(state, EV_SYN, SYN_DROPPED, 0);
    QCOMPARE(dropped.action, EvdevTouchService::TouchAction::Release);
    QVERIFY(dropped.reconnect);

    EvdevTouchService::processInputEvent(state, EV_ABS, ABS_X, 999);
    EvdevTouchService::processInputEvent(state, EV_KEY, BTN_TOUCH, 1);
    QCOMPARE(EvdevTouchService::processInputEvent(state, EV_SYN, SYN_REPORT, 0).action,
             EvdevTouchService::TouchAction::None);
    QCOMPARE(state.x, 0);
    QVERIFY(!state.pressed);
}

void EvdevTouchServiceTests::rejectsDirectAbsoluteDeviceWithoutTouchSignal()
{
    EvdevTouchService::DeviceCandidate candidate;
    candidate.direct = true;
    candidate.hasAbsX = true;
    candidate.hasAbsY = true;

    QCOMPARE(EvdevTouchService::candidateScore(candidate), -1);
}

void EvdevTouchServiceTests::rejectsIndirectTouchpadDuringAutomaticSelection()
{
    EvdevTouchService::DeviceCandidate touchpad;
    touchpad.hasAbsX = true;
    touchpad.hasAbsY = true;
    touchpad.hasBtnTouch = true;

    QCOMPARE(EvdevTouchService::candidateScore(touchpad), -1);
}

void EvdevTouchServiceTests::cancellingInputReleasesAnActivePress()
{
    EvdevTouchService::InputState state;
    state.pressed = true;
    state.x = 123;
    state.y = 456;

    const auto update = EvdevTouchService::cancelInput(state);
    QCOMPARE(update.action, EvdevTouchService::TouchAction::Release);
    QCOMPARE(update.x, 123);
    QCOMPARE(update.y, 456);
    QVERIFY(!state.pressed);
}

void EvdevTouchServiceTests::mapsPressMoveReleaseAndCancellationThroughCalibration()
{
    EvdevTouchService service(nullptr);
    service.absXMin_ = 0;
    service.absXMax_ = 100;
    service.absYMin_ = 0;
    service.absYMax_ = 100;
    service.calibrationTransform_ = TouchAffineTransform::rotation(90);

    for (const auto action : {EvdevTouchService::TouchAction::Press,
                              EvdevTouchService::TouchAction::Move,
                              EvdevTouchService::TouchAction::Release}) {
        const EvdevTouchService::TouchUpdate update{action, 25, 75, false};
        QCOMPARE(service.normalizedPosition(update), QPointF(0.25, 0.25));
    }

    EvdevTouchService::InputState state;
    state.pressed = true;
    state.x = 25;
    state.y = 75;
    QCOMPARE(service.normalizedPosition(EvdevTouchService::cancelInput(state)),
             QPointF(0.25, 0.25));
}

void EvdevTouchServiceTests::loadsCalibrationProfileForSelectedStableIdentity()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("touch-calibration.json"));
    const EvdevTouchService::DeviceIdentity identity{
        3, 0x1234, 0x5678, 1, QStringLiteral("Panel"), QStringLiteral("usb-1/input0")};
    const QString stableIdentity = stableTouchscreenIdentity(
        identity.busType, identity.vendor, identity.product, identity.version,
        identity.name, identity.physical);
    TouchCalibrationStore store(path);
    QVERIFY(store.saveProfile(stableIdentity, TouchAffineTransform::rotation(90)));

    EvdevTouchService service(nullptr);
    service.calibrationStoragePath_ = path;
    service.selectedIdentity_ = identity;
    service.loadCalibrationProfile();
    service.absXMin_ = 0;
    service.absXMax_ = 100;
    service.absYMin_ = 0;
    service.absYMax_ = 100;

    QCOMPARE(service.normalizedPosition({EvdevTouchService::TouchAction::Press, 25, 75}),
             QPointF(0.25, 0.25));
}

void EvdevTouchServiceTests::emitsUncalibratedRawCoordinatesForCalibration()
{
    EvdevTouchService service(nullptr);
    service.absXMin_ = 0;
    service.absXMax_ = 100;
    service.absYMin_ = 0;
    service.absYMax_ = 100;
    service.calibrationTransform_ = TouchAffineTransform::rotation(90);
    QSignalSpy pressedSpy(&service, &EvdevTouchService::rawTouchPressed);

    service.dispatchTouchUpdate({EvdevTouchService::TouchAction::Press, 25, 75});

    QCOMPARE(pressedSpy.size(), 1);
    QCOMPARE(pressedSpy.first().at(0).toPointF(), QPointF(0.25, 0.75));
}

void EvdevTouchServiceTests::exposesCalibrationDeviceStateAndPersistence()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    QFile activeDevice(directory.filePath(QStringLiteral("event-test")));
    QVERIFY(activeDevice.open(QIODevice::ReadWrite));

    EvdevTouchService service(nullptr);
    service.fd_ = ::dup(activeDevice.handle());
    QVERIFY(service.fd_ >= 0);
    service.devicePath_ = activeDevice.fileName();
    service.selectedIdentity_ = {3, 0x1234, 0x5678, 1,
                                 QStringLiteral("Xeneon Edge Touchscreen"),
                                 QStringLiteral("usb-test/input0")};
    service.calibrationStoragePath_ = directory.filePath(QStringLiteral("touch-calibration.json"));
    const QString stableIdentity = stableTouchscreenIdentity(
        3, 0x1234, 0x5678, 1, QStringLiteral("Xeneon Edge Touchscreen"),
        QStringLiteral("usb-test/input0"));

    QVERIFY(service.isAvailable());
    QCOMPARE(service.deviceName(), QStringLiteral("Xeneon Edge Touchscreen"));
    QCOMPARE(service.deviceIdentity(), stableIdentity);
    QCOMPARE(service.statusText(), QStringLiteral("Direct touch input active"));
    QVERIFY(!service.hasCalibration());

    QString error;
    QVERIFY2(service.saveCalibration(TouchAffineTransform::rotation(90), &error),
             qPrintable(error));
    QVERIFY(service.hasCalibration());
    QVERIFY(TouchCalibrationStore(service.calibrationStoragePath_).hasProfile(stableIdentity));

    QVERIFY2(service.resetCalibration(&error), qPrintable(error));
    QVERIFY(!service.hasCalibration());
    QVERIFY(!TouchCalibrationStore(service.calibrationStoragePath_).hasProfile(stableIdentity));
}

void EvdevTouchServiceTests::calibrationPathHonorsIsolatedConfigDirectory()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QByteArray previousOverride = qgetenv("CIDERDECK_CONFIG_DIR");
    qputenv("CIDERDECK_CONFIG_DIR", directory.path().toUtf8());

    EvdevTouchService service(nullptr);

    if (previousOverride.isNull())
        qunsetenv("CIDERDECK_CONFIG_DIR");
    else
        qputenv("CIDERDECK_CONFIG_DIR", previousOverride);
    QCOMPARE(service.calibrationStoragePath_,
             directory.filePath(QStringLiteral("touch-calibration.json")));
}

} // namespace ciderdeck

QTEST_GUILESS_MAIN(ciderdeck::EvdevTouchServiceTests)

#include "EvdevTouchServiceTests.moc"
