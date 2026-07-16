import QtQuick

Card {
    id: brightnessTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1
    readonly property real railScale: Math.max(0.9, Math.min(1.35, contentScale))

    readonly property var monitors: {
        var raw = settings.brightnessMonitors
        if (!raw || raw.length === 0) return []
        if (typeof raw === "string") {
            try { return JSON.parse(raw) } catch (error) { return [] }
        }
        return raw
    }
    readonly property bool multiMonitor: monitors.length > 0
    property int currentMonitorIndex: 0
    readonly property int displayIndex: multiMonitor && currentMonitorIndex < monitors.length
        ? (monitors[currentMonitorIndex].id || 0)
        : 0
    readonly property string monitorName: multiMonitor && currentMonitorIndex < monitors.length
        ? shortenedMonitorName(monitors[currentMonitorIndex].name || "DISPLAY")
        : "DISPLAY"
    property var localValues: ({})
    property bool dragging: false

    readonly property real currentValue: {
        if (localValues[displayIndex] !== undefined) return localValues[displayIndex]
        var serviceValue = brightnessService.getBrightness(displayIndex)
        if (serviceValue >= 0) return serviceValue / 100
        return Math.max(0, brightnessService.brightness / 100)
    }
    readonly property bool available: brightnessService.getBrightness(displayIndex) >= 0
                                            || brightnessService.brightness >= 0

    function shortenedMonitorName(name) {
        var value = String(name)
        var colon = value.indexOf(":")
        if (colon > 0) value = value.substring(0, colon)
        return value.toUpperCase()
    }

    function setLocalValue(index, value) {
        var copy = Object.assign({}, localValues)
        copy[index] = value
        localValues = copy
    }

    function selectMonitor(delta) {
        if (monitors.length < 2) return
        currentMonitorIndex = (currentMonitorIndex + delta + monitors.length) % monitors.length
    }

    Timer {
        id: ddcThrottle
        interval: 180
        property int pendingValue: -1
        property int pendingDisplay: -1
        onTriggered: {
            if (pendingValue >= 0) {
                brightnessService.setBrightness(pendingDisplay, pendingValue)
                pendingValue = -1
            }
        }
    }

    function requestBrightness(value) {
        var normalized = Math.max(0.01, Math.min(1, value))
        setLocalValue(displayIndex, normalized)
        var percent = Math.round(normalized * 100)
        if (!ddcThrottle.running) {
            brightnessService.setBrightness(displayIndex, percent)
            ddcThrottle.start()
        } else {
            ddcThrottle.pendingDisplay = displayIndex
            ddcThrottle.pendingValue = percent
        }
    }

    Connections {
        target: brightnessService
        function onDisplayBrightnessChanged(index, percent) {
            if (!brightnessTile.dragging) brightnessTile.setLocalValue(index, percent / 100)
        }
        function onBrightnessChanged() {
            if (!brightnessTile.dragging && !brightnessTile.multiMonitor) {
                brightnessTile.setLocalValue(0, brightnessService.brightness / 100)
            }
        }
    }

    VerticalSlider {
        anchors.fill: parent
        anchors.bottomMargin: brightnessTile.monitors.length > 1 ? 44 : 12
        label: "Brightness"
        detail: brightnessTile.monitorName
        value: brightnessTile.currentValue
        available: brightnessTile.available
        accentColor: settings.barColor || "#f6c85f"
        sliderThickness: settings.sliderThickness || 1
        knobSize: settings.knobSize || 1
        knobShape: settings.knobShape || "pill"
        knobColor: settings.knobColor || "#f5f7fa"
        iconColor: settings.iconColor || "#f6c85f"
        valueColor: settings.percentColor || themeManager.textColor
        showValue: settings.showPercent !== false
        showIcon: settings.showIcon !== false
        iconSource: "qrc:/icons/lucide/sun.svg"
        contentScale: brightnessTile.railScale
        onValueRequested: (value) => brightnessTile.requestBrightness(value)
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        spacing: 8
        visible: brightnessTile.monitors.length > 1

        IconTouchButton {
            width: 34; height: 34; iconSize: 15
            source: "qrc:/icons/lucide/chevron-left.svg"
            onClicked: brightnessTile.selectMonitor(-1)
        }
        IconTouchButton {
            width: 34; height: 34; iconSize: 15
            source: "qrc:/icons/lucide/chevron-right.svg"
            onClicked: brightnessTile.selectMonitor(1)
        }
    }
}
