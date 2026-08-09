#include <QTest>

#include "services/TouchCalibrationService.h"

using namespace ciderdeck;

namespace {

class FakeTouchCalibrationDevice final : public TouchCalibrationDevice {
public:
    bool isAvailable() const override { return available; }
    QString deviceName() const override { return QStringLiteral("Xeneon Edge Touchscreen"); }
    QString devicePath() const override { return QStringLiteral("/dev/input/event-test"); }
    QString deviceIdentity() const override { return QStringLiteral("evdev-v1:test-device"); }
    QString statusText() const override { return QStringLiteral("Direct touch input active"); }
    bool hasCalibration() const override { return calibrated; }
    TouchAffineTransform currentCalibration() const override { return current; }
    void useCalibration(const TouchAffineTransform &transform) override { current = transform; }
    bool saveCalibration(const TouchAffineTransform &transform, QString *) override
    {
        ++saveCount;
        current = transform;
        calibrated = true;
        return true;
    }
    bool resetCalibration(QString *) override
    {
        ++resetCount;
        current = TouchAffineTransform::identity();
        calibrated = false;
        return true;
    }
    void setCalibrationCaptureActive(bool active) override { captureActive = active; }

    bool available = true;
    bool calibrated = false;
    int saveCount = 0;
    int resetCount = 0;
    bool captureActive = false;
    TouchAffineTransform current;
};

void collectIdentityCalibration(TouchCalibrationService &service)
{
    const QList<QPointF> targets{
        {0.1, 0.1}, {0.9, 0.1}, {0.9, 0.9}, {0.1, 0.9}, {0.5, 0.5},
    };
    for (const QPointF &target : targets) {
        service.touchPressed(target);
        service.touchReleased(target);
    }
}

} // namespace

class TouchCalibrationServiceTests : public QObject {
    Q_OBJECT

private slots:
    void sequencesFiveTargetsIntoPreview();
    void boundsAndAveragesRecentContactSamples();
    void cancelRestoresOriginalWithoutPersisting();
    void applyPersistsPreviewAndClosesSession();
    void retryReturnsToPreviousPoint();
    void poorFitShowsErrorAndRetryStartsOver();
    void exposesDeviceDiagnosticsAndResetsPersistedProfile();
    void previewMapsRawTouchThroughCandidate();
    void captureSuppressesForwardedInputUntilSessionEnds();
};

void TouchCalibrationServiceTests::sequencesFiveTargetsIntoPreview()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    const QList<QPointF> expectedTargets{
        {0.1, 0.1}, {0.9, 0.1}, {0.9, 0.9}, {0.1, 0.9}, {0.5, 0.5},
    };

    QVERIFY(service.start());
    QCOMPARE(service.stageName(), QStringLiteral("collecting"));
    for (qsizetype index = 0; index < expectedTargets.size(); ++index) {
        QCOMPARE(service.currentPoint(), index);
        QCOMPARE(service.targetPoint(), expectedTargets.at(index));
        service.touchPressed(expectedTargets.at(index));
        service.touchReleased(expectedTargets.at(index));
        QCOMPARE(service.acknowledgedPointCount(), index + 1);
    }

    QCOMPARE(service.stageName(), QStringLiteral("preview"));
    QVERIFY(service.canApply());
}

void TouchCalibrationServiceTests::boundsAndAveragesRecentContactSamples()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    QVERIFY(service.start());

    service.touchPressed(QPointF(0.8, 0.8));
    for (int i = 0; i < 20; ++i)
        service.touchMoved(QPointF(0.1, 0.1));

    QCOMPARE(service.contactSampleCount(), 12);
    service.touchReleased(QPointF(0.1, 0.1));
    QCOMPARE(service.lastAcceptedInputPoint(), QPointF(0.1, 0.1));
}

void TouchCalibrationServiceTests::cancelRestoresOriginalWithoutPersisting()
{
    FakeTouchCalibrationDevice device;
    device.current = TouchAffineTransform::rotation(90);
    const auto original = device.current.coefficients();
    TouchCalibrationService service(&device);

    QVERIFY(service.start());
    collectIdentityCalibration(service);
    QCOMPARE(service.stageName(), QStringLiteral("preview"));
    QCOMPARE(device.saveCount, 0);
    QVERIFY(device.current.coefficients() != original);

    service.cancel();

    QCOMPARE(service.stageName(), QStringLiteral("idle"));
    QCOMPARE(device.current.coefficients(), original);
    QCOMPARE(device.saveCount, 0);
}

void TouchCalibrationServiceTests::applyPersistsPreviewAndClosesSession()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    QVERIFY(service.start());
    collectIdentityCalibration(service);

    QVERIFY(service.apply());

    QCOMPARE(device.saveCount, 1);
    QVERIFY(device.calibrated);
    QCOMPARE(service.stageName(), QStringLiteral("idle"));
}

void TouchCalibrationServiceTests::retryReturnsToPreviousPoint()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    QVERIFY(service.start());
    for (const QPointF &target : {QPointF(0.1, 0.1), QPointF(0.9, 0.1)}) {
        service.touchPressed(target);
        service.touchReleased(target);
    }
    QCOMPARE(service.currentPoint(), 2);

    service.retry();

    QCOMPARE(service.currentPoint(), 1);
    QCOMPARE(service.acknowledgedPointCount(), 1);
    QCOMPARE(service.targetPoint(), QPointF(0.9, 0.1));
}

void TouchCalibrationServiceTests::poorFitShowsErrorAndRetryStartsOver()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    QVERIFY(service.start());
    for (int i = 0; i < 5; ++i) {
        service.touchPressed(QPointF(0.5, 0.5));
        service.touchReleased(QPointF(0.5, 0.5));
    }

    QCOMPARE(service.stageName(), QStringLiteral("error"));
    QVERIFY(service.errorMessage().contains(QStringLiteral("directional spread")));

    service.retry();

    QCOMPARE(service.stageName(), QStringLiteral("collecting"));
    QCOMPARE(service.acknowledgedPointCount(), 0);
    QVERIFY(service.errorMessage().isEmpty());
}

void TouchCalibrationServiceTests::exposesDeviceDiagnosticsAndResetsPersistedProfile()
{
    FakeTouchCalibrationDevice device;
    device.calibrated = true;
    device.current = TouchAffineTransform::rotation(90);
    TouchCalibrationService service(&device);

    QVERIFY(service.deviceAvailable());
    QCOMPARE(service.deviceName(), QStringLiteral("Xeneon Edge Touchscreen"));
    QCOMPARE(service.devicePath(), QStringLiteral("/dev/input/event-test"));
    QCOMPARE(service.deviceIdentity(), QStringLiteral("evdev-v1:test-device"));
    QCOMPARE(service.statusText(), QStringLiteral("Direct touch input active"));
    QVERIFY(service.hasCalibration());

    QVERIFY(service.reset());

    QCOMPARE(device.resetCount, 1);
    QVERIFY(!service.hasCalibration());
    QCOMPARE(device.current.coefficients(), TouchAffineTransform::identity().coefficients());
}

void TouchCalibrationServiceTests::previewMapsRawTouchThroughCandidate()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);
    QVERIFY(service.start());
    collectIdentityCalibration(service);

    service.touchPressed(QPointF(0.3, 0.4));
    QCOMPARE(service.previewPosition(), QPointF(0.3, 0.4));

    service.touchMoved(QPointF(0.2, 0.7));
    QCOMPARE(service.previewPosition(), QPointF(0.2, 0.7));

    service.touchReleased(QPointF(0.8, 0.6));
    QCOMPARE(service.previewPosition(), QPointF(0.8, 0.6));
}

void TouchCalibrationServiceTests::captureSuppressesForwardedInputUntilSessionEnds()
{
    FakeTouchCalibrationDevice device;
    TouchCalibrationService service(&device);

    QVERIFY(service.start());
    QVERIFY(device.captureActive);

    service.cancel();
    QVERIFY(!device.captureActive);
}

QTEST_GUILESS_MAIN(TouchCalibrationServiceTests)

#include "TouchCalibrationServiceTests.moc"
