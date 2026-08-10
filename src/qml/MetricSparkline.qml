import QtQuick

Canvas {
    id: chart

    property var values: []
    property real maxValue: 100
    property bool presentationActive: true
    property color lineColor: themeManager.accentColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.12)
    readonly property int transitionDuration: 900
    property var fromValues: []
    property var toValues: []
    property real fromCeiling: 100
    property real toCeiling: 100
    property real transitionProgress: 1
    property bool transitionReady: false
    readonly property real displayedCeiling:
        fromCeiling + (toCeiling - fromCeiling) * transitionProgress

    antialiasing: true
    renderTarget: Canvas.FramebufferObject

    function finiteNumber(value) {
        var number = Number(value)
        return isFinite(number) ? number : 0
    }

    function copyValues(source) {
        var copied = []
        if (!source)
            return copied

        for (var i = 0; i < source.length; i++)
            copied.push(finiteNumber(source[i]))
        return copied
    }

    function ceilingFor(source) {
        var configuredMax = finiteNumber(maxValue)
        if (configuredMax > 0)
            return configuredMax

        var ceiling = 1
        for (var m = 0; m < source.length; m++)
            ceiling = Math.max(ceiling, finiteNumber(source[m]))
        ceiling *= 1.15
        return ceiling
    }

    function sampledValue(source, index, count) {
        if (!source || source.length === 0)
            return 0
        if (source.length === 1 || count <= 1)
            return finiteNumber(source[0])

        var position = index * (source.length - 1) / (count - 1)
        var leftIndex = Math.floor(position)
        var rightIndex = Math.min(source.length - 1, leftIndex + 1)
        var fraction = position - leftIndex
        var leftValue = finiteNumber(source[leftIndex])
        var rightValue = finiteNumber(source[rightIndex])
        return leftValue + (rightValue - leftValue) * fraction
    }

    function interpolatedValues() {
        var count = Math.max(fromValues.length, toValues.length)
        var interpolated = []
        for (var i = 0; i < count; i++) {
            var oldValue = sampledValue(fromValues, i, count)
            var newValue = sampledValue(toValues, i, count)
            interpolated.push(oldValue + (newValue - oldValue) * transitionProgress)
        }
        return interpolated
    }

    function synchronizePresentation() {
        if (!presentationActive)
            return

        var nextValues = copyValues(values)
        var nextCeiling = ceilingFor(nextValues)
        morphAnimation.stop()
        fromValues = nextValues
        toValues = nextValues
        fromCeiling = nextCeiling
        toCeiling = nextCeiling
        transitionProgress = 1
        requestPaint()
    }

    function beginTransition() {
        if (!presentationActive)
            return

        var nextValues = copyValues(values)
        var nextCeiling = ceilingFor(nextValues)

        if (!transitionReady || toValues.length < 2 || nextValues.length < 2) {
            synchronizePresentation()
            return
        }

        var currentValues = interpolatedValues()
        var currentCeiling = displayedCeiling
        morphAnimation.stop()
        fromValues = currentValues
        toValues = nextValues
        fromCeiling = currentCeiling
        toCeiling = nextCeiling
        transitionProgress = 0
        morphAnimation.restart()
    }

    Component.onCompleted: {
        transitionReady = true
        if (presentationActive)
            synchronizePresentation()
    }

    onValuesChanged: {
        if (transitionReady && presentationActive)
            beginTransition()
    }
    onMaxValueChanged: {
        if (transitionReady && presentationActive)
            beginTransition()
    }
    onPresentationActiveChanged: {
        if (!transitionReady)
            return

        if (presentationActive)
            synchronizePresentation()
        else
            morphAnimation.stop()
    }
    onTransitionProgressChanged: {
        if (presentationActive)
            requestPaint()
    }
    onLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    NumberAnimation {
        id: morphAnimation
        target: chart
        property: "transitionProgress"
        from: 0
        to: 1
        duration: chart.transitionDuration
        easing.type: Easing.OutCubic
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 1 || height <= 1)
            return

        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
        ctx.lineWidth = 1
        for (var guide = 1; guide <= 2; guide++) {
            var guideY = Math.round(height * guide / 3) + 0.5
            ctx.beginPath()
            ctx.moveTo(0, guideY)
            ctx.lineTo(width, guideY)
            ctx.stroke()
        }

        var displayedValues = chart.interpolatedValues()
        if (displayedValues.length < 2)
            return

        var ceiling = Math.max(1, chart.displayedCeiling)
        var step = width / Math.max(1, displayedValues.length - 1)
        function pointY(value) {
            return height - Math.max(0, Math.min(1, Number(value) / ceiling)) * (height - 3) - 1
        }

        ctx.beginPath()
        ctx.moveTo(0, height)
        for (var i = 0; i < displayedValues.length; i++)
            ctx.lineTo(i * step, pointY(displayedValues[i]))
        ctx.lineTo(width, height)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()

        ctx.beginPath()
        for (var j = 0; j < displayedValues.length; j++) {
            var x = j * step
            var y = pointY(displayedValues[j])
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
