import QtQuick

Canvas {
    id: chart

    property var values: []
    property real maxValue: 100
    property color lineColor: themeManager.accentColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.12)

    antialiasing: true
    renderTarget: Canvas.FramebufferObject

    onValuesChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

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

        if (!values || values.length < 2)
            return

        var ceiling = maxValue
        if (ceiling <= 0) {
            ceiling = 1
            for (var m = 0; m < values.length; m++)
                ceiling = Math.max(ceiling, Number(values[m]))
            ceiling *= 1.15
        }

        var step = width / Math.max(1, values.length - 1)
        function pointY(value) {
            return height - Math.max(0, Math.min(1, Number(value) / ceiling)) * (height - 3) - 1
        }

        ctx.beginPath()
        ctx.moveTo(0, height)
        for (var i = 0; i < values.length; i++)
            ctx.lineTo(i * step, pointY(values[i]))
        ctx.lineTo(width, height)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()

        ctx.beginPath()
        for (var j = 0; j < values.length; j++) {
            var x = j * step
            var y = pointY(values[j])
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
