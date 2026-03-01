import QtQuick

Card {
    id: brightnessTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property bool isVertical: height > width
    readonly property bool showIcon: settings.showIcon !== false
    readonly property bool showPercent: settings.showPercent !== false

    // Standard slider sizing (see DESIGN-SYSTEM.md § Sliders)
    readonly property real sliderScale: settings.sliderThickness || 1.0
    readonly property real trackThick: 8 * sliderScale
    readonly property real knobScale: settings.knobSize || 1.0
    readonly property string knobShape: settings.knobShape || "pill"
    readonly property real knobBase: trackThick + 12 * knobScale
    // Shape-specific dimensions: pill=capsule, circle=perfect circle, square=rounded rect
    readonly property real thumbCross: knobShape === "square" ? knobBase * 0.85 : knobBase
    readonly property real thumbAlong: knobShape === "circle" ? knobBase
        : knobShape === "square" ? knobBase * 0.85
        : Math.max(knobBase * 0.55, 8)  // pill — wide & short capsule
    readonly property real thumbRadius: knobShape === "circle" ? knobBase / 2
        : knobShape === "square" ? 3
        : thumbAlong / 2  // pill — fully rounded ends

    // Icon size
    readonly property real iconSize: 18 * contentScale

    // Slider colors (see DESIGN-SYSTEM.md § Slider Colors)
    readonly property color iconColor: settings.iconColor || "#FFD54F"
    readonly property color barColor: settings.barColor || "#FFD54F"
    readonly property color knobColor: settings.knobColor || "white"
    readonly property color percentColor: settings.percentColor || themeManager.textColor

    // --- Multi-monitor support ---
    readonly property var brightnessMonitors: {
        var raw = settings.brightnessMonitors
        if (!raw || raw.length === 0) return []
        if (typeof raw === "string") {
            try { return JSON.parse(raw) } catch(e) { return [] }
        }
        return raw
    }
    readonly property bool multiMonitor: brightnessMonitors.length > 0
    property int currentMonitorIdx: 0

    // Current display index into brightnessService
    readonly property int currentDisplayIndex: {
        if (!multiMonitor) return 0
        if (currentMonitorIdx < 0 || currentMonitorIdx >= brightnessMonitors.length) return 0
        return brightnessMonitors[currentMonitorIdx].id || 0
    }

    // Current monitor display name
    readonly property string monitorLabel: {
        if (!multiMonitor) return ""
        if (currentMonitorIdx >= 0 && currentMonitorIdx < brightnessMonitors.length)
            return brightnessMonitors[currentMonitorIdx].name || ""
        return ""
    }

    // Per-display local brightness (decoupled from service during drag)
    property var localBrightnessMap: ({})
    property bool dragging: false

    readonly property real localBrightness: {
        var key = currentDisplayIndex
        if (localBrightnessMap[key] !== undefined) return localBrightnessMap[key]
        var svcVal = brightnessService.getBrightness(key)
        return svcVal >= 0 ? svcVal / 100 : brightnessService.brightness / 100
    }

    function setLocalBrightness(displayIdx, val) {
        var newMap = Object.assign({}, localBrightnessMap)
        newMap[displayIdx] = val
        localBrightnessMap = newMap
    }

    Connections {
        target: brightnessService
        function onDisplayBrightnessChanged(displayIndex, percent) {
            if (!brightnessTile.dragging) {
                brightnessTile.setLocalBrightness(displayIndex, percent / 100)
            }
        }
        function onBrightnessChanged() {
            if (!brightnessTile.dragging && !brightnessTile.multiMonitor) {
                brightnessTile.setLocalBrightness(0, brightnessService.brightness / 100)
            }
        }
    }

    // Throttle DDC calls during drag (max every 200ms)
    Timer {
        id: ddcThrottle
        interval: 200
        property int pendingPercent: -1
        property int pendingDisplayIdx: -1
        onTriggered: {
            if (pendingPercent >= 0) {
                brightnessService.setBrightness(pendingDisplayIdx, pendingPercent)
                pendingPercent = -1
            }
        }
    }

    function throttledSet(displayIdx, percent) {
        if (!ddcThrottle.running) {
            brightnessService.setBrightness(displayIdx, percent)
            ddcThrottle.start()
        } else {
            ddcThrottle.pendingPercent = percent
            ddcThrottle.pendingDisplayIdx = displayIdx
        }
    }

    function selectNextMonitor() {
        if (brightnessMonitors.length <= 1) return
        currentMonitorIdx = (currentMonitorIdx + 1) % brightnessMonitors.length
    }

    function selectPreviousMonitor() {
        if (brightnessMonitors.length <= 1) return
        currentMonitorIdx = (currentMonitorIdx - 1 + brightnessMonitors.length) % brightnessMonitors.length
    }

    // --- Swipe state ---
    property real swipeStartX: 0
    property real swipeStartY: 0
    property bool isSwiping: false

    // Outer Item provides consistent padding (matches volume tile)
    Item {
        anchors.fill: parent
        anchors.margins: 8

        // --- VERTICAL LAYOUT (icon top, slider middle, percent bottom) ---
        Column {
            anchors.fill: parent
            spacing: 4
            visible: brightnessTile.isVertical

            // Sun icon at top
            Item {
                width: parent.width
                height: sunBtnV.height
                visible: brightnessTile.showIcon

                Rectangle {
                    id: sunBtnV
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32 * brightnessTile.contentScale
                    height: 32 * brightnessTile.contentScale
                    radius: width / 2
                    color: "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: brightnessTile.iconSize
                        height: brightnessTile.iconSize
                        source: "qrc:/icons/lucide/sun.svg"
                        color: brightnessTile.iconColor
                    }
                }
            }

            // Monitor label (when multi-monitor)
            Text {
                id: monitorLabelV
                anchors.horizontalCenter: parent.horizontalCenter
                visible: brightnessTile.multiMonitor && brightnessTile.monitorLabel !== ""
                text: brightnessTile.monitorLabel
                color: themeManager.secondaryTextColor
                font.pixelSize: 10 * brightnessTile.contentScale
                elide: Text.ElideRight
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            // Slider track (fills remaining space)
            Item {
                width: parent.width
                height: parent.height
                       - (brightnessTile.showIcon ? sunBtnV.height + 4 : 0)
                       - (brightnessTile.showPercent ? percentV.height + 4 : 0)
                       - (brightnessTile.multiMonitor && brightnessTile.monitorLabel !== "" ? monitorLabelV.height + 4 : 0)
                       - (brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1 ? monitorDotsV.height + 4 : 0)

                Rectangle {
                    id: vTrack
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: brightnessTile.trackThick
                    radius: brightnessTile.trackThick / 2
                    color: themeManager.borderColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.min(brightnessTile.localBrightness, 1)
                        radius: brightnessTile.trackThick / 2
                        color: brightnessTile.barColor

                        Behavior on height { enabled: !brightnessTile.dragging; NumberAnimation { duration: 80 } }
                    }

                    Rectangle {
                        width: brightnessTile.thumbCross
                        height: brightnessTile.thumbAlong
                        radius: brightnessTile.thumbRadius
                        color: brightnessTile.knobColor
                        border.width: 1
                        border.color: themeManager.borderColor
                        x: (parent.width - width) / 2
                        y: Math.max(0, Math.min(parent.height - height,
                            parent.height * (1 - Math.min(brightnessTile.localBrightness, 1)) - height / 2))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    property real pressX: 0
                    property real pressY: 0
                    property bool gestureLocked: false
                    property bool isSwipeGesture: false
                    readonly property bool canSwipe: brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1

                    function updateVal(mouse) {
                        var percent = 1 - ((mouse.y - vTrack.y) / vTrack.height)
                        percent = Math.max(0.01, Math.min(1, percent))
                        var dispIdx = brightnessTile.currentDisplayIndex
                        brightnessTile.setLocalBrightness(dispIdx, percent)
                        brightnessTile.throttledSet(dispIdx, Math.round(percent * 100))
                    }

                    onPressed: (mouse) => {
                        pressX = mouse.x; pressY = mouse.y
                        gestureLocked = false; isSwipeGesture = false
                        brightnessTile.isSwiping = false
                        if (!canSwipe) { gestureLocked = true; isSwipeGesture = false }
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        if (!gestureLocked) {
                            var dx = Math.abs(mouse.x - pressX)
                            var dy = Math.abs(mouse.y - pressY)
                            if (dx > 15 || dy > 15) {
                                isSwipeGesture = dx > dy
                                gestureLocked = true
                                if (isSwipeGesture) brightnessTile.isSwiping = true
                                else brightnessTile.dragging = true
                            }
                            return  // Don't move slider until gesture is decided
                        }
                        if (!isSwipeGesture) updateVal(mouse)
                    }
                    onReleased: (mouse) => {
                        if (isSwipeGesture) {
                            var deltaX = mouse.x - pressX
                            if (deltaX > 40) brightnessTile.selectPreviousMonitor()
                            else if (deltaX < -40) brightnessTile.selectNextMonitor()
                        } else if (!gestureLocked) {
                            brightnessTile.dragging = true
                            updateVal(mouse)
                        }
                        if (brightnessTile.dragging) {
                            brightnessTile.dragging = false
                            var dispIdx = brightnessTile.currentDisplayIndex
                            brightnessService.setBrightness(dispIdx, Math.round(brightnessTile.localBrightness * 100))
                        }
                        brightnessTile.isSwiping = false
                    }
                    onCanceled: { brightnessTile.dragging = false; brightnessTile.isSwiping = false }
                }
            }

            // Percent at bottom
            Text {
                id: percentV
                anchors.horizontalCenter: parent.horizontalCenter
                visible: brightnessTile.showPercent
                text: Math.round(brightnessTile.localBrightness * 100) + "%"
                color: brightnessTile.percentColor
                font.pixelSize: 13 * brightnessTile.contentScale
                font.weight: Font.DemiBold
            }

            // Indicator dots (vertical tile — at bottom)
            Row {
                id: monitorDotsV
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                visible: brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1

                Repeater {
                    model: brightnessTile.brightnessMonitors.length
                    Rectangle {
                        required property int index
                        width: 6 * brightnessTile.contentScale
                        height: width
                        radius: width / 2
                        color: index === brightnessTile.currentMonitorIdx ? themeManager.accentColor : themeManager.borderColor
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2
                            onClicked: brightnessTile.currentMonitorIdx = parent.index
                        }
                    }
                }
            }
        }

        // --- HORIZONTAL LAYOUT (icon left, slider middle, percent right) ---
        Row {
            anchors.fill: parent
            spacing: 6
            visible: !brightnessTile.isVertical

            // Sun icon at left
            Item {
                width: sunBtnH.width
                height: parent.height
                visible: brightnessTile.showIcon

                Rectangle {
                    id: sunBtnH
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * brightnessTile.contentScale
                    height: 32 * brightnessTile.contentScale
                    radius: width / 2
                    color: "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: brightnessTile.iconSize
                        height: brightnessTile.iconSize
                        source: "qrc:/icons/lucide/sun.svg"
                        color: brightnessTile.iconColor
                    }
                }
            }

            // Middle column: monitor label + slider + dots
            Column {
                width: parent.width
                       - (brightnessTile.showIcon ? sunBtnH.width + 6 : 0)
                       - (brightnessTile.showPercent ? percentH.width + 6 : 0)
                height: parent.height
                spacing: 2

                // Monitor label
                Text {
                    id: monitorLabelH
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: brightnessTile.multiMonitor && brightnessTile.monitorLabel !== ""
                    text: brightnessTile.monitorLabel
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * brightnessTile.contentScale
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                // Slider track
                Item {
                    width: parent.width
                    height: parent.height
                           - (brightnessTile.multiMonitor && brightnessTile.monitorLabel !== "" ? monitorLabelH.height + 2 : 0)
                           - (brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1 ? monitorDotsH.height + 2 : 0)

                    Rectangle {
                        id: hTrack
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: brightnessTile.trackThick
                        radius: brightnessTile.trackThick / 2
                        color: themeManager.borderColor

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width * Math.min(brightnessTile.localBrightness, 1)
                            radius: brightnessTile.trackThick / 2
                            color: brightnessTile.barColor

                            Behavior on width { enabled: !brightnessTile.dragging; NumberAnimation { duration: 80 } }
                        }

                        Rectangle {
                            width: brightnessTile.thumbAlong   // swap for horizontal
                            height: brightnessTile.thumbCross
                            radius: brightnessTile.thumbRadius
                            color: brightnessTile.knobColor
                            border.width: 1
                            border.color: themeManager.borderColor
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * Math.min(brightnessTile.localBrightness, 1) - width / 2))
                            y: (parent.height - height) / 2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true

                        property real pressX: 0
                        property real pressY: 0
                        property bool gestureLocked: false
                        property bool isSwipeGesture: false
                        readonly property bool canSwipe: brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1

                        function updateVal(mouse) {
                            var percent = (mouse.x - hTrack.x) / hTrack.width
                            percent = Math.max(0.01, Math.min(1, percent))
                            var dispIdx = brightnessTile.currentDisplayIndex
                            brightnessTile.setLocalBrightness(dispIdx, percent)
                            brightnessTile.throttledSet(dispIdx, Math.round(percent * 100))
                        }

                        onPressed: (mouse) => {
                            pressX = mouse.x; pressY = mouse.y
                            gestureLocked = false; isSwipeGesture = false
                            brightnessTile.isSwiping = false
                            if (!canSwipe) { gestureLocked = true; isSwipeGesture = false }
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            if (!gestureLocked) {
                                var dx = Math.abs(mouse.x - pressX)
                                var dy = Math.abs(mouse.y - pressY)
                                if (dx > 15 || dy > 15) {
                                    isSwipeGesture = dy > dx
                                    gestureLocked = true
                                    if (isSwipeGesture) brightnessTile.isSwiping = true
                                    else brightnessTile.dragging = true
                                }
                                return  // Don't move slider until gesture is decided
                            }
                            if (!isSwipeGesture) updateVal(mouse)
                        }
                        onReleased: (mouse) => {
                            if (isSwipeGesture) {
                                var deltaY = pressY - mouse.y
                                if (deltaY > 40) brightnessTile.selectNextMonitor()
                                else if (deltaY < -40) brightnessTile.selectPreviousMonitor()
                            } else if (!gestureLocked) {
                                brightnessTile.dragging = true
                                updateVal(mouse)
                            }
                            if (brightnessTile.dragging) {
                                brightnessTile.dragging = false
                                var dispIdx = brightnessTile.currentDisplayIndex
                                brightnessService.setBrightness(dispIdx, Math.round(brightnessTile.localBrightness * 100))
                            }
                            brightnessTile.isSwiping = false
                        }
                        onCanceled: { brightnessTile.dragging = false; brightnessTile.isSwiping = false }
                    }
                }

                // Indicator dots (horizontal tile — at bottom)
                Row {
                    id: monitorDotsH
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    visible: brightnessTile.multiMonitor && brightnessTile.brightnessMonitors.length > 1

                    Repeater {
                        model: brightnessTile.brightnessMonitors.length
                        Rectangle {
                            required property int index
                            width: 6 * brightnessTile.contentScale
                            height: width
                            radius: width / 2
                            color: index === brightnessTile.currentMonitorIdx ? themeManager.accentColor : themeManager.borderColor
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -2
                                onClicked: brightnessTile.currentMonitorIdx = parent.index
                            }
                        }
                    }
                }
            }

            // Percent at right
            Text {
                id: percentH
                anchors.verticalCenter: parent.verticalCenter
                visible: brightnessTile.showPercent
                text: Math.round(brightnessTile.localBrightness * 100) + "%"
                color: brightnessTile.percentColor
                font.pixelSize: 13 * brightnessTile.contentScale
                font.weight: Font.DemiBold
            }
        }

        // Swipe detection is integrated into the slider MouseAreas above
    }
}
