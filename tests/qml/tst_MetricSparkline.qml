import QtQuick 2.15
import QtTest 1.3
import "../../src/qml"

TestCase {
    id: testCase

    name: "MetricSparkline"
    when: windowShown

    Component {
        id: sparklineComponent

        MetricSparkline {
            width: 200
            height: 60
            lineColor: "#ffffff"
            fillColor: "transparent"
        }
    }

    Component {
        id: signalSpyComponent

        SignalSpy {
            signalName: "painted"
        }
    }

    function createSparkline(properties) {
        var sparkline = sparklineComponent.createObject(testCase, properties || {})
        verify(sparkline !== null)
        return sparkline
    }

    function test_nonFiniteHistoryValuesAreSanitizedBeforeInterpolation() {
        var sparkline = createSparkline()
        var sanitized = sparkline.copyValues([NaN, Infinity, -Infinity, -5, 42])

        compare(sanitized, [0, 0, 0, -5, 42])
        for (var i = 0; i < sanitized.length; i++)
            verify(isFinite(sanitized[i]))

        sparkline.destroy()
    }

    function test_nonFiniteMaximumIsSanitizedBeforeCeilingArithmetic() {
        var sparkline = createSparkline({ "maxValue": Infinity })
        var ceiling = sparkline.ceilingFor([10, 20])

        verify(isFinite(ceiling))
        compare(ceiling, 23)

        sparkline.destroy()
    }

    function test_nonFiniteHistoryCannotPoisonDynamicCeilingArithmetic() {
        var sparkline = createSparkline({ "maxValue": 0 })
        var ceiling = sparkline.ceilingFor([10, Infinity, -Infinity, NaN, -5])

        verify(isFinite(ceiling))
        compare(ceiling, 11.5)

        sparkline.destroy()
    }

    function test_nonFiniteTransitionEndpointsAreSanitizedBeforeInterpolation() {
        var sparkline = createSparkline()
        sparkline.fromValues = [10, Infinity, -5]
        sparkline.toValues = [20, 30, -10]
        sparkline.transitionProgress = 0.5

        var interpolated = sparkline.interpolatedValues()
        compare(interpolated, [15, 15, -7.5])
        for (var i = 0; i < interpolated.length; i++)
            verify(isFinite(interpolated[i]))

        sparkline.destroy()
    }

    function test_inactiveSampleChangesDoNotUpdateOrRepaintPresentationState() {
        var sparkline = createSparkline({
            "presentationActive": false,
            "values": [10, 20],
            "maxValue": 100
        })
        var paintSpy = signalSpyComponent.createObject(testCase, { "target": sparkline })
        verify(paintSpy !== null)
        wait(30)
        paintSpy.clear()

        sparkline.values = [30, Infinity, -10]
        sparkline.maxValue = 200
        wait(50)

        compare(sparkline.fromValues, [])
        compare(sparkline.toValues, [])
        compare(sparkline.fromCeiling, 100)
        compare(sparkline.toCeiling, 100)
        compare(sparkline.transitionProgress, 1)
        compare(paintSpy.count, 0)

        paintSpy.destroy()
        sparkline.destroy()
    }

    function test_activationSnapsToLatestSanitizedHistoryAndScale() {
        var sparkline = createSparkline({
            "presentationActive": false,
            "values": [10, 20],
            "maxValue": 100
        })
        sparkline.values = [30, Infinity, -10]
        sparkline.maxValue = 200

        sparkline.presentationActive = true
        wait(20)

        compare(sparkline.fromValues, [30, 0, -10])
        compare(sparkline.toValues, [30, 0, -10])
        compare(sparkline.fromCeiling, 200)
        compare(sparkline.toCeiling, 200)
        compare(sparkline.transitionProgress, 1)

        sparkline.destroy()
    }

    function test_deactivationStopsTheInFlightMorph() {
        var sparkline = createSparkline({
            "presentationActive": true,
            "values": [10, 20],
            "maxValue": 100
        })
        sparkline.values = [30, 40]
        wait(80)
        verify(sparkline.transitionProgress > 0)
        verify(sparkline.transitionProgress < 1)

        sparkline.presentationActive = false
        wait(30)
        var frozenProgress = sparkline.transitionProgress
        wait(120)

        compare(sparkline.transitionProgress, frozenProgress)

        sparkline.destroy()
    }
}
