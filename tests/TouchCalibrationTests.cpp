#include <QtTest/QTest>

#include <QTemporaryDir>
#include <QFile>
#include <cmath>
#include <limits>

#include "models/TouchCalibration.h"

using namespace ciderdeck;

class TouchCalibrationTests : public QObject {
    Q_OBJECT

private slots:
    void identityLeavesNormalizedCoordinatesUnchanged();
    void knownAffineTransformMapsNormalizedCoordinates();
    void mappedCoordinatesAreClampedToNormalizedBounds();
    void nonFiniteCoefficientsFallBackToIdentity();
    void quarterTurnRotationsMapNormalizedCoordinates();
    void composesRotationAndFlipsInOrder();
    void fitsAffineTransformFromNoisyFivePointSamples();
    void rejectsUnsafeInputGeometry_data();
    void rejectsUnsafeInputGeometry();
    void acceptsSafeCalibrationGeometryBoundary();
    void classifiesDirectionalSpreadBoundaryConsistently();
    void acceptsFullScreenCalibrationTransforms();
    void acceptsMaximumSafeLinearAmplification();
    void acceptsMaximumSafeLinearAmplificationInGeneralOrientations();
    void acceptsOneUlpLinearAmplificationNeighborhood();
    void rejectsExcessiveLinearAmplification_data();
    void rejectsExcessiveLinearAmplification();
    void rejectsNonFiniteDerivedLinearAmplification();
    void rejectsHugeMixedAxisTransformsWhoseSafetyMetricsOverflow();
    void rejectsDegenerateAndPoorCalibrationFits();
    void persistsAndLooksUpProfilesByStableDeviceIdentity();
    void malformedLegacyAndUnknownSettingsFallBackToIdentity();
    void mapsEvdevCoordinatesThroughDeviceCalibrationBeforePixels();
    void mapsExtremeEvdevRangesWithoutOverflow();
    void invalidEvdevRangesReturnSafeOrigin();
};

void TouchCalibrationTests::identityLeavesNormalizedCoordinatesUnchanged()
{
    const TouchAffineTransform transform = TouchAffineTransform::identity();

    QCOMPARE(transform.map(QPointF(0.25, 0.75)), QPointF(0.25, 0.75));
    QVERIFY(transform.isValid());
}

void TouchCalibrationTests::knownAffineTransformMapsNormalizedCoordinates()
{
    const TouchAffineTransform transform({0.5, 0.0, 0.1, 0.0, 0.25, 0.2});

    QCOMPARE(transform.map(QPointF(0.4, 0.8)), QPointF(0.3, 0.4));
}

void TouchCalibrationTests::mappedCoordinatesAreClampedToNormalizedBounds()
{
    const TouchAffineTransform transform({2.0, 0.0, -0.25, 0.0, 2.0, 0.25});

    QCOMPARE(transform.map(QPointF(1.0, -1.0)), QPointF(1.0, 0.0));
}

void TouchCalibrationTests::nonFiniteCoefficientsFallBackToIdentity()
{
    const TouchAffineTransform transform(
        {1.0, 0.0, std::numeric_limits<double>::infinity(), 0.0, 1.0, 0.0});

    QVERIFY(!transform.isValid());
    QCOMPARE(transform.map(QPointF(0.2, 0.7)), QPointF(0.2, 0.7));
}

void TouchCalibrationTests::quarterTurnRotationsMapNormalizedCoordinates()
{
    const QPointF point(0.2, 0.7);

    QCOMPARE(TouchAffineTransform::rotation(90).map(point), QPointF(0.3, 0.2));
    QCOMPARE(TouchAffineTransform::rotation(180).map(point), QPointF(0.8, 0.3));
    QCOMPARE(TouchAffineTransform::rotation(270).map(point), QPointF(0.7, 0.8));
}

void TouchCalibrationTests::composesRotationAndFlipsInOrder()
{
    const TouchAffineTransform transform = TouchAffineTransform::rotation(90).then(
        TouchAffineTransform::flipped(true, false));

    QCOMPARE(transform.map(QPointF(0.2, 0.7)), QPointF(0.7, 0.2));
    QCOMPARE(TouchAffineTransform::flipped(false, true).map(QPointF(0.2, 0.7)),
             QPointF(0.2, 0.3));
}

void TouchCalibrationTests::fitsAffineTransformFromNoisyFivePointSamples()
{
    const QList<TouchCalibrationSample> samples{
        {{0.1, 0.1}, {0.141, 0.181}},
        {{0.9, 0.1}, {0.779, 0.099}},
        {{0.1, 0.9}, {0.221, 0.901}},
        {{0.9, 0.9}, {0.861, 0.819}},
        {{0.5, 0.5}, {0.501, 0.499}},
    };
    QString error;

    const auto fitted = TouchAffineTransform::fit(samples, 0.02, &error);

    QVERIFY2(fitted.has_value(), qPrintable(error));
    const QPointF mapped = fitted->map(QPointF(0.4, 0.6));
    QVERIFY(qAbs(mapped.x() - 0.43) < 0.01);
    QVERIFY(qAbs(mapped.y() - 0.60) < 0.01);
}

void TouchCalibrationTests::rejectsUnsafeInputGeometry_data()
{
    QTest::addColumn<double>("minorAxisSpan");
    QTest::newRow("review-span-0.000002") << 0.000002;
    QTest::newRow("near-review-span-below-0.004") << 0.0039;
    QTest::newRow("review-span-0.004") << 0.004;
    QTest::newRow("near-review-span-above-0.004") << 0.0041;
    QTest::newRow("small-two-percent-span") << 0.02;
    QTest::newRow("just-below-five-percent-directional-spread") << 0.12;
}

void TouchCalibrationTests::rejectsUnsafeInputGeometry()
{
    QFETCH(double, minorAxisSpan);
    const QList<TouchCalibrationSample> samples{
        {{0.0, 0.0}, {0.0, 0.0}},
        {{1.0, 0.0}, {1.0, 0.0}},
        {{0.0, minorAxisSpan}, {0.0, 1.0}},
    };
    QString error;

    QVERIFY(!TouchAffineTransform::fit(samples, 0.01, &error).has_value());
    QCOMPARE(error, QStringLiteral("Calibration input geometry lacks independent directional spread"));
}

void TouchCalibrationTests::acceptsSafeCalibrationGeometryBoundary()
{
    const QList<TouchCalibrationSample> samples{
        {{0.0, 0.0}, {0.0, 0.0}},
        {{1.0, 0.0}, {1.0, 0.0}},
        {{0.0, 0.123}, {0.0, 0.123}},
    };
    QString error;

    QVERIFY2(TouchAffineTransform::fit(samples, 0.01, &error).has_value(), qPrintable(error));
    QVERIFY(error.isEmpty());
}

void TouchCalibrationTests::classifiesDirectionalSpreadBoundaryConsistently()
{
    constexpr double pi = 3.14159265358979323846;
    struct BoundaryCase {
        double spread;
        bool expectedAccepted;
        const char *description;
    };
    const BoundaryCase cases[]{
        {0.0499, false, "materially below"},
        {std::nextafter(0.05, 0.0), true, "one ULP below"},
        {0.05, true, "exact boundary"},
        {std::nextafter(0.05, std::numeric_limits<double>::infinity()),
         true, "one ULP above"},
        {0.0501, true, "materially above"},
    };

    for (const BoundaryCase &boundary : cases) {
        const double radius = boundary.spread * std::sqrt(2.5);
        for (int degrees = 0; degrees < 360; ++degrees) {
            const double radians = degrees * pi / 180.0;
            const double cosine = std::cos(radians);
            const double sine = std::sin(radians);
            const QList<QPointF> centeredInputs{
                {radius, 0.0}, {-radius, 0.0}, {0.0, radius}, {0.0, -radius}, {0.0, 0.0},
            };
            QList<TouchCalibrationSample> samples;
            for (const QPointF &centered : centeredInputs) {
                const QPointF input(0.5 + cosine * centered.x() - sine * centered.y(),
                                    0.5 + sine * centered.x() + cosine * centered.y());
                samples.append({input, input});
            }
            QString error;

            const bool accepted = TouchAffineTransform::fit(samples, 1e-9, &error).has_value();
            QVERIFY2(accepted == boundary.expectedAccepted,
                     qPrintable(QStringLiteral("%1 at rotation %2: %3")
                                    .arg(QString::fromLatin1(boundary.description))
                                    .arg(degrees).arg(error)));
        }
    }
}

void TouchCalibrationTests::acceptsFullScreenCalibrationTransforms()
{
    const QList<QPointF> inputs{
        {0.1, 0.1}, {0.9, 0.1}, {0.1, 0.9}, {0.9, 0.9}, {0.5, 0.5},
    };
    const QList<TouchAffineTransform> expectedTransforms{
        TouchAffineTransform::identity(),
        TouchAffineTransform::rotation(90),
        TouchAffineTransform::rotation(180),
        TouchAffineTransform::rotation(270),
        TouchAffineTransform::flipped(true, false),
        TouchAffineTransform::flipped(false, true),
        TouchAffineTransform({1.25, 0.0, -0.125, 0.0, 1.25, -0.125}),
    };

    for (const TouchAffineTransform &expected : expectedTransforms) {
        QList<TouchCalibrationSample> samples;
        for (const QPointF &input : inputs)
            samples.append({input, expected.map(input)});
        QString error;

        const auto fitted = TouchAffineTransform::fit(samples, 0.000001, &error);
        QVERIFY2(fitted.has_value(), qPrintable(error));
        const QPointF expectedPoint = expected.map(QPointF(0.4, 0.6));
        const QPointF fittedPoint = fitted->map(QPointF(0.4, 0.6));
        QVERIFY(qAbs(fittedPoint.x() - expectedPoint.x()) < 1e-9);
        QVERIFY(qAbs(fittedPoint.y() - expectedPoint.y()) < 1e-9);
    }
}

void TouchCalibrationTests::acceptsMaximumSafeLinearAmplification()
{
    constexpr double pi = 3.14159265358979323846;
    const QList<QPointF> centeredInputs{
        {-0.2, -0.2}, {0.2, -0.2}, {-0.2, 0.2}, {0.2, 0.2}, {0.0, 0.0},
    };

    for (int degrees = 0; degrees < 360; ++degrees) {
        const double radians = degrees * pi / 180.0;
        const double cosine = std::cos(radians);
        const double sine = std::sin(radians);
        QList<TouchCalibrationSample> samples;
        for (const QPointF &centered : centeredInputs) {
            const QPointF input(0.5 + cosine * centered.x() - sine * centered.y(),
                                0.5 + sine * centered.x() + cosine * centered.y());
            const QPointF target(0.5 + 2.0 * centered.x(),
                                 0.5 + 2.0 * centered.y());
            samples.append({input, target});
        }
        QString error;

        QVERIFY2(TouchAffineTransform::fit(samples, 1e-9, &error).has_value(),
                 qPrintable(QStringLiteral("rotation %1: %2").arg(degrees).arg(error)));
        QVERIFY(error.isEmpty());
    }
}

void TouchCalibrationTests::acceptsMaximumSafeLinearAmplificationInGeneralOrientations()
{
    constexpr double pi = 3.14159265358979323846;
    const QList<QPointF> inputs{
        {0.3, 0.3}, {0.7, 0.3}, {0.3, 0.7}, {0.7, 0.7}, {0.5, 0.5},
    };

    for (double minorAmplification : {0.6, 1.3, 1.9}) {
        for (int leftDegrees = 0; leftDegrees < 360; leftDegrees += 15) {
            for (int rightDegrees = 0; rightDegrees < 360; rightDegrees += 17) {
                const double left = leftDegrees * pi / 180.0;
                const double right = rightDegrees * pi / 180.0;
                const double leftCosine = std::cos(left);
                const double leftSine = std::sin(left);
                const double rightCosine = std::cos(right);
                const double rightSine = std::sin(right);
                const double xx = 2.0 * leftCosine * rightCosine
                    + minorAmplification * leftSine * rightSine;
                const double xy = 2.0 * leftCosine * rightSine
                    - minorAmplification * leftSine * rightCosine;
                const double yx = 2.0 * leftSine * rightCosine
                    - minorAmplification * leftCosine * rightSine;
                const double yy = 2.0 * leftSine * rightSine
                    + minorAmplification * leftCosine * rightCosine;
                QList<TouchCalibrationSample> samples;
                for (const QPointF &input : inputs) {
                    const double centeredX = input.x() - 0.5;
                    const double centeredY = input.y() - 0.5;
                    samples.append({input,
                                    {0.5 + xx * centeredX + xy * centeredY,
                                     0.5 + yx * centeredX + yy * centeredY}});
                }
                QString error;

                QVERIFY2(TouchAffineTransform::fit(samples, 1e-9, &error).has_value(),
                         qPrintable(QStringLiteral("minor %1, orientations %2/%3: %4")
                                        .arg(minorAmplification).arg(leftDegrees)
                                        .arg(rightDegrees).arg(error)));
            }
        }
    }
}

void TouchCalibrationTests::acceptsOneUlpLinearAmplificationNeighborhood()
{
    const double amplifications[]{
        std::nextafter(2.0, 0.0),
        2.0,
        std::nextafter(2.0, std::numeric_limits<double>::infinity()),
    };
    const QList<QPointF> inputs{
        {0.3, 0.3}, {0.7, 0.3}, {0.3, 0.7}, {0.7, 0.7}, {0.5, 0.5},
    };

    for (double amplification : amplifications) {
        QList<TouchCalibrationSample> samples;
        for (const QPointF &input : inputs) {
            samples.append({input,
                            {0.5 + amplification * (input.x() - 0.5),
                             0.5 + amplification * (input.y() - 0.5)}});
        }
        QString error;

        QVERIFY2(TouchAffineTransform::fit(samples, 1e-9, &error).has_value(),
                 qPrintable(QStringLiteral("amplification %1: %2")
                                .arg(amplification, 0, 'g', 17).arg(error)));
    }
}

void TouchCalibrationTests::rejectsExcessiveLinearAmplification_data()
{
    QTest::addColumn<double>("amplification");
    QTest::newRow("just-above-two-times") << 2.0001;
    QTest::newRow("two-and-a-half-times") << 2.5;
}

void TouchCalibrationTests::rejectsExcessiveLinearAmplification()
{
    QFETCH(double, amplification);
    constexpr double pi = 3.14159265358979323846;
    const QList<QPointF> centeredInputs{
        {-0.2, -0.2}, {0.2, -0.2}, {-0.2, 0.2}, {0.2, 0.2}, {0.0, 0.0},
    };

    for (int degrees = 0; degrees < 360; ++degrees) {
        const double radians = degrees * pi / 180.0;
        const double cosine = std::cos(radians);
        const double sine = std::sin(radians);
        QList<TouchCalibrationSample> samples;
        for (const QPointF &centered : centeredInputs) {
            const QPointF input(0.5 + cosine * centered.x() - sine * centered.y(),
                                0.5 + sine * centered.x() + cosine * centered.y());
            const QPointF target(0.5 + amplification * centered.x(),
                                 0.5 + amplification * centered.y());
            samples.append({input, target});
        }
        QString error;

        QVERIFY(!TouchAffineTransform::fit(samples, 0.01, &error).has_value());
        QCOMPARE(error, QStringLiteral("Calibration transform amplification exceeds safe limit"));
    }
}

void TouchCalibrationTests::rejectsNonFiniteDerivedLinearAmplification()
{
    const double xAmplification = std::ldexp(1.0, 520);
    const QList<QPointF> inputs{
        {0.0, 0.0}, {1.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}, {0.5, 0.5},
    };
    QList<TouchCalibrationSample> samples;
    for (const QPointF &input : inputs)
        samples.append({input, {xAmplification * input.x(), input.y()}});
    QString error;

    QVERIFY(!TouchAffineTransform::fit(samples, 0.0, &error).has_value());
    QCOMPARE(error, QStringLiteral("Calibration transform amplification exceeds safe limit"));
}

void TouchCalibrationTests::rejectsHugeMixedAxisTransformsWhoseSafetyMetricsOverflow()
{
    const double huge = std::ldexp(1.0, 520);
    struct LinearTransformCase {
        double xx;
        double xy;
        double yx;
        double yy;
        const char *description;
    };
    const LinearTransformCase transforms[]{
        {huge, huge, huge, -huge, "reviewer mixed-axis cancellation"},
        {huge, -huge, huge, huge, "quarter-turn orientation"},
        {-huge, huge, huge, huge, "reflected orientation"},
        {huge, huge, -huge, huge, "opposite mixed-axis signs"},
    };
    const QList<QPointF> inputs{
        {0.0, 0.0}, {1.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}, {0.5, 0.5},
    };

    for (const LinearTransformCase &transform : transforms) {
        QList<TouchCalibrationSample> samples;
        for (const QPointF &input : inputs) {
            samples.append({input,
                            {transform.xx * input.x() + transform.xy * input.y(),
                             transform.yx * input.x() + transform.yy * input.y()}});
        }
        QString error;

        QVERIFY2(!TouchAffineTransform::fit(samples, 0.0, &error).has_value(),
                 transform.description);
        QCOMPARE(error, QStringLiteral("Calibration transform amplification exceeds safe limit"));
    }
}

void TouchCalibrationTests::rejectsDegenerateAndPoorCalibrationFits()
{
    const QList<TouchCalibrationSample> degenerate{
        {{0.1, 0.1}, {0.1, 0.1}}, {{0.2, 0.2}, {0.2, 0.2}}, {{0.3, 0.3}, {0.3, 0.3}}};
    QVERIFY(!TouchAffineTransform::fit(degenerate, 0.01).has_value());

    const QList<TouchCalibrationSample> poor{
        {{0.0, 0.0}, {0.0, 0.0}}, {{1.0, 0.0}, {1.0, 0.0}},
        {{0.0, 1.0}, {0.0, 1.0}}, {{1.0, 1.0}, {0.0, 0.0}},
        {{0.5, 0.5}, {1.0, 1.0}}};
    QVERIFY(!TouchAffineTransform::fit(poor, 0.05).has_value());
}

void TouchCalibrationTests::persistsAndLooksUpProfilesByStableDeviceIdentity()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    TouchCalibrationStore store(directory.filePath(QStringLiteral("touch-calibration.json")));
    QString error;

    QVERIFY2(store.saveProfile(QStringLiteral("usb:1234:5678:panel-a"),
                               TouchAffineTransform({0.8, 0.0, 0.1, 0.0, 0.9, 0.05}), &error),
             qPrintable(error));

    const TouchAffineTransform restored = store.profileFor(
        QStringLiteral("usb:1234:5678:panel-a"), &error);
    const std::array<double, 6> expected{0.8, 0.0, 0.1, 0.0, 0.9, 0.05};
    QCOMPARE(restored.coefficients(), expected);
    QVERIFY(error.isEmpty());
    QCOMPARE(store.profileFor(QStringLiteral("other-device")).coefficients(),
             TouchAffineTransform::identity().coefficients());
}

void TouchCalibrationTests::malformedLegacyAndUnknownSettingsFallBackToIdentity()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("touch-calibration.json"));
    TouchCalibrationStore store(path);

    for (const QByteArray &contents : {
             QByteArrayLiteral("{\"legacyOption\":true}"),
             QByteArrayLiteral("{\"version\":99,\"profiles\":[]}"),
             QByteArrayLiteral("{\"version\":1,\"profiles\":[{\"deviceId\":\"panel\",\"coefficients\":[1,0,\"bad\",0,1,0]}]}")}) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        QCOMPARE(file.write(contents), contents.size());
        file.close();
        QString error;
        QCOMPARE(store.profileFor(QStringLiteral("panel"), &error).coefficients(),
                 TouchAffineTransform::identity().coefficients());
        QVERIFY(!error.isEmpty());
    }
}

void TouchCalibrationTests::mapsEvdevCoordinatesThroughDeviceCalibrationBeforePixels()
{
    QCOMPARE(mapEvdevToNormalized(25, 75, 0, 100, 0, 100,
                                  TouchAffineTransform::rotation(90)),
             QPointF(0.25, 0.25));
    const QString first = stableTouchscreenIdentity(
        3, 0x1234, 0x5678, 1, QStringLiteral("Panel"), QStringLiteral("usb-1/input0"));
    const QString second = stableTouchscreenIdentity(
        3, 0x1234, 0x5678, 1, QStringLiteral("Panel"), QStringLiteral("usb-1/input0"));
    QCOMPARE(first, second);
    QVERIFY(first != stableTouchscreenIdentity(
        3, 0x1234, 0x5678, 1, QStringLiteral("Panel"), QStringLiteral("usb-2/input0")));
}

void TouchCalibrationTests::mapsExtremeEvdevRangesWithoutOverflow()
{
    const int minimum = std::numeric_limits<int>::min();
    const int maximum = std::numeric_limits<int>::max();

    QCOMPARE(mapEvdevToNormalized(minimum, minimum, minimum, maximum, minimum, maximum,
                                  TouchAffineTransform::identity()),
             QPointF(0.0, 0.0));
    QCOMPARE(mapEvdevToNormalized(maximum, maximum, minimum, maximum, minimum, maximum,
                                  TouchAffineTransform::identity()),
             QPointF(1.0, 1.0));

    const QPointF midpoint = mapEvdevToNormalized(
        0, 0, minimum, maximum, minimum, maximum, TouchAffineTransform::identity());
    const double expected = static_cast<double>(-static_cast<qint64>(minimum))
        / (static_cast<qint64>(maximum) - static_cast<qint64>(minimum));
    QVERIFY(qAbs(midpoint.x() - expected) < 1e-12);
    QVERIFY(qAbs(midpoint.y() - expected) < 1e-12);
}

void TouchCalibrationTests::invalidEvdevRangesReturnSafeOrigin()
{
    QCOMPARE(mapEvdevToNormalized(25, 75, 100, 100, 0, 100,
                                  TouchAffineTransform::rotation(90)),
             QPointF(0.0, 0.0));
    QCOMPARE(mapEvdevToNormalized(25, 75, 100, 0, 0, 100,
                                  TouchAffineTransform::identity()),
             QPointF(0.0, 0.0));
    QCOMPARE(mapEvdevToNormalized(25, 75, 0, 100, 100, 0,
                                  TouchAffineTransform::identity()),
             QPointF(0.0, 0.0));
}

QTEST_GUILESS_MAIN(TouchCalibrationTests)

#include "TouchCalibrationTests.moc"
