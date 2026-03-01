import QtQuick

Card {
    id: volumeTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property bool isVertical: height > width
    readonly property bool showPercent: settings.showPercent !== false
    readonly property bool showMuteBtn: settings.showMuteBtn !== false

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

    // Slider colors (see DESIGN-SYSTEM.md § Slider Colors)
    readonly property color iconColor: settings.iconColor || themeManager.textColor
    readonly property color barColor: settings.barColor || themeManager.accentColor
    readonly property color knobColor: settings.knobColor || "white"
    readonly property color percentColor: settings.percentColor || themeManager.textColor

    // --- Multi-device support ---
    readonly property var volumeDevices: {
        var raw = settings.volumeDevices
        if (!raw || raw.length === 0) return []
        // raw is a JSON array stored as a QML variant
        if (typeof raw === "string") {
            try { return JSON.parse(raw) } catch(e) { return [] }
        }
        return raw
    }
    readonly property bool multiDevice: volumeDevices.length > 0
    property int currentDeviceIdx: 0

    // Resolve the current device to a model index (or app-level match)
    function resolveDevice(deviceIdx) {
        if (!multiDevice || deviceIdx < 0 || deviceIdx >= volumeDevices.length) return null
        var dev = volumeDevices[deviceIdx]
        var devType = dev.type || "sink"
        var devName = dev.name || ""
        var matchBy = dev.matchBy || "stream"
        if (devName === "") return null

        // App-level matching: find ALL streams for this app
        if (matchBy === "app") {
            var streamType = devType === "sourceOutput" ? "sourceOutput" : "sinkInput"
            if (!audioManager) return { type: streamType, index: -1, available: false, matchBy: "app", appName: devName, streamType: streamType }
            var streams = audioManager.findStreamsByApp(devName, streamType)
            return { type: streamType, index: -1, available: streams.length > 0, matchBy: "app", appName: devName, streamType: streamType }
        }

        // Stream-level matching (original behavior)
        var count = audioManager ? audioManager.deviceCount(devType) : 0
        for (var i = 0; i < count; i++) {
            if (audioManager.deviceDescription(devType, i) === devName
                || audioManager.deviceName(devType, i) === devName) {
                return { type: devType, index: i, available: true, matchBy: "stream" }
            }
        }
        return { type: devType, index: -1, available: false, matchBy: "stream" }
    }

    readonly property var currentResolved: {
        void(_audioTick) // re-resolve when devices appear/disappear
        return resolveDevice(currentDeviceIdx)
    }
    readonly property bool deviceAvailable: !multiDevice || (currentResolved !== null && currentResolved.available)
    readonly property string currentDeviceType: multiDevice && currentResolved ? currentResolved.type : "sink"

    // Bind to refreshTick so QML re-evaluates Q_INVOKABLE calls when model data changes
    readonly property int _audioTick: audioManager ? audioManager.refreshTick : 0

    // Current volume/mute — either from resolved device or default sink
    readonly property real currentVolume: {
        void(_audioTick) // force re-evaluation on tick change
        if (multiDevice && currentResolved && currentResolved.available && audioManager) {
            if (currentResolved.matchBy === "app")
                return audioManager.appVolume(currentResolved.appName, currentResolved.streamType || "sinkInput") / 100
            return audioManager.deviceVolume(currentResolved.type, currentResolved.index) / 100
        }
        return audioManager ? audioManager.defaultVolume / 100 : 0.75
    }
    readonly property bool isMuted: {
        void(_audioTick) // force re-evaluation on tick change
        if (multiDevice && currentResolved && currentResolved.available && audioManager) {
            if (currentResolved.matchBy === "app")
                return audioManager.appMuted(currentResolved.appName, currentResolved.streamType || "sinkInput")
            return audioManager.deviceMuted(currentResolved.type, currentResolved.index)
        }
        return audioManager ? audioManager.defaultMuted : false
    }

    // Current device display name and icon
    readonly property string deviceLabel: {
        if (!multiDevice) return ""
        if (currentDeviceIdx >= 0 && currentDeviceIdx < volumeDevices.length)
            return volumeDevices[currentDeviceIdx].name || ""
        return ""
    }
    readonly property string deviceIcon: {
        if (!multiDevice) return ""
        if (currentDeviceIdx >= 0 && currentDeviceIdx < volumeDevices.length)
            return volumeDevices[currentDeviceIdx].icon || ""
        return ""
    }
    readonly property string deviceLabelMode: settings.deviceLabelMode || "text"

    // Icon logic: mic for source/sourceOutput devices, speaker otherwise
    readonly property bool isSourceDevice: currentDeviceType === "source" || currentDeviceType === "sourceOutput"
    readonly property string activeIcon: {
        if (isSourceDevice) {
            return isMuted ? "qrc:/icons/lucide/mic-off.svg" : "qrc:/icons/lucide/mic.svg"
        }
        return isMuted ? "qrc:/icons/lucide/volume-x.svg" : "qrc:/icons/lucide/volume-2.svg"
    }

    function setVolume(percent) {
        if (!audioManager) return
        if (multiDevice && currentResolved && currentResolved.available) {
            if (currentResolved.matchBy === "app")
                audioManager.setAppVolume(currentResolved.appName, percent, currentResolved.streamType || "sinkInput")
            else
                audioManager.setDeviceVolume(currentResolved.type, currentResolved.index, percent)
        } else if (!multiDevice) {
            audioManager.setDefaultVolume(percent)
        }
    }

    function toggleMute() {
        if (!audioManager) return
        if (multiDevice && currentResolved && currentResolved.available) {
            if (currentResolved.matchBy === "app")
                audioManager.setAppMuted(currentResolved.appName, !isMuted, currentResolved.streamType || "sinkInput")
            else
                audioManager.setDeviceMuted(currentResolved.type, currentResolved.index, !isMuted)
        } else if (!multiDevice) {
            audioManager.setDefaultMuted(!isMuted)
        }
    }

    function selectNextDevice() {
        if (volumeDevices.length <= 1) return
        currentDeviceIdx = (currentDeviceIdx + 1) % volumeDevices.length
    }

    function selectPreviousDevice() {
        if (volumeDevices.length <= 1) return
        currentDeviceIdx = (currentDeviceIdx - 1 + volumeDevices.length) % volumeDevices.length
    }

    // --- Swipe state ---
    property real swipeStartX: 0
    property real swipeStartY: 0
    property bool isSwiping: false

    Item {
        anchors.fill: parent
        anchors.margins: 8

        // --- VERTICAL LAYOUT ---
        Column {
            anchors.fill: parent
            spacing: 4
            visible: volumeTile.isVertical

            // Mute button at top (with icon switching)
            Item {
                width: parent.width
                height: muteColBtn.height
                visible: volumeTile.showMuteBtn

                Rectangle {
                    id: muteColBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32 * volumeTile.contentScale
                    height: 32 * volumeTile.contentScale
                    radius: width / 2
                    color: muteColArea.containsMouse ? themeManager.overlayColor : "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 18 * volumeTile.contentScale
                        height: 18 * volumeTile.contentScale
                        source: volumeTile.activeIcon
                        color: volumeTile.iconColor
                    }

                    MouseArea {
                        id: muteColArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: volumeTile.toggleMute()
                    }
                }
            }

            // Device label (when multi-device)
            Item {
                id: deviceLabelV
                anchors.horizontalCenter: parent.horizontalCenter
                visible: volumeTile.multiDevice && (volumeTile.deviceLabel !== "" || volumeTile.deviceIcon !== "")
                width: parent.width
                height: deviceLabelVContent.height

                Row {
                    id: deviceLabelVContent
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Image {
                        visible: volumeTile.deviceIcon !== "" && (volumeTile.deviceLabelMode === "icon" || volumeTile.deviceLabelMode === "both")
                        source: volumeTile.deviceIcon
                        sourceSize.width: 14 * volumeTile.contentScale
                        sourceSize.height: 14 * volumeTile.contentScale
                        width: 14 * volumeTile.contentScale
                        height: 14 * volumeTile.contentScale
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: volumeTile.deviceAvailable ? 1.0 : 0.3
                    }

                    Text {
                        visible: volumeTile.deviceLabelMode === "text" || volumeTile.deviceLabelMode === "both"
                                 || volumeTile.deviceIcon === ""
                        text: volumeTile.deviceAvailable ? volumeTile.deviceLabel : "Unavailable"
                        color: volumeTile.deviceAvailable ? themeManager.secondaryTextColor : themeManager.errorColor
                        font.pixelSize: 10 * volumeTile.contentScale
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Slider track (fills remaining space)
            Item {
                width: parent.width
                height: parent.height
                       - (volumeTile.showMuteBtn ? muteColBtn.height + 4 : 0)
                       - (volumeTile.showPercent ? volPercentCol.height + 4 : 0)
                       - (volumeTile.multiDevice && volumeTile.deviceLabel !== "" ? deviceLabelV.height + 4 : 0)
                       - (volumeTile.multiDevice && volumeTile.volumeDevices.length > 1 ? dotsV.height + 4 : 0)

                opacity: volumeTile.deviceAvailable ? 1.0 : 0.3

                Rectangle {
                    id: vTrack
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: volumeTile.trackThick
                    radius: volumeTile.trackThick / 2
                    color: themeManager.borderColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.min(volumeTile.currentVolume, 1)
                        radius: volumeTile.trackThick / 2
                        color: volumeTile.isMuted ? themeManager.secondaryTextColor : volumeTile.barColor
                    }

                    Rectangle {
                        width: volumeTile.thumbCross
                        height: volumeTile.thumbAlong
                        radius: volumeTile.thumbRadius
                        color: volumeTile.knobColor
                        border.width: 1
                        border.color: themeManager.borderColor
                        x: (parent.width - width) / 2
                        y: Math.max(0, Math.min(parent.height - height,
                            parent.height * (1 - Math.min(volumeTile.currentVolume, 1)) - height / 2))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    property real pressX: 0
                    property real pressY: 0
                    property bool gestureLocked: false
                    property bool isSwipeGesture: false
                    readonly property bool canSwipe: volumeTile.multiDevice && volumeTile.volumeDevices.length > 1

                    onPressed: (mouse) => {
                        pressX = mouse.x; pressY = mouse.y
                        gestureLocked = false; isSwipeGesture = false
                        volumeTile.isSwiping = false
                        // If no multi-device, immediately lock as slider (no dead zone)
                        if (!canSwipe) { gestureLocked = true; isSwipeGesture = false }
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        if (!gestureLocked) {
                            var dx = Math.abs(mouse.x - pressX)
                            var dy = Math.abs(mouse.y - pressY)
                            if (dx > 15 || dy > 15) {
                                // Vertical tile: horizontal drag = swipe, vertical drag = slider
                                isSwipeGesture = dx > dy
                                gestureLocked = true
                                if (isSwipeGesture) volumeTile.isSwiping = true
                            }
                            return  // Don't move slider until gesture is decided
                        }
                        if (!isSwipeGesture) updateVol(mouse)
                    }
                    onReleased: (mouse) => {
                        if (isSwipeGesture) {
                            var deltaX = mouse.x - pressX
                            if (deltaX > 40) volumeTile.selectPreviousDevice()
                            else if (deltaX < -40) volumeTile.selectNextDevice()
                        } else if (!gestureLocked) {
                            // Tap — set volume to tap position
                            updateVol(mouse)
                        }
                        volumeTile.isSwiping = false
                    }

                    function updateVol(mouse) {
                        if (!volumeTile.deviceAvailable) return
                        var trackTop = vTrack.y
                        var trackH = vTrack.height
                        var percent = 1 - ((mouse.y - trackTop) / trackH)
                        percent = Math.max(0, Math.min(1, percent))
                        volumeTile.setVolume(Math.round(percent * 100))
                    }
                }
            }

            // Percent at bottom
            Text {
                id: volPercentCol
                anchors.horizontalCenter: parent.horizontalCenter
                visible: volumeTile.showPercent
                text: {
                    var val = Math.round(volumeTile.currentVolume * 100)
                    return val + "%"
                }
                color: volumeTile.isMuted ? themeManager.secondaryTextColor : volumeTile.percentColor
                font.pixelSize: 13 * volumeTile.contentScale
                font.weight: Font.DemiBold
            }

            // Indicator dots (vertical tile — at bottom)
            Row {
                id: dotsV
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                visible: volumeTile.multiDevice && volumeTile.volumeDevices.length > 1

                Repeater {
                    model: volumeTile.volumeDevices.length
                    Rectangle {
                        required property int index
                        width: 6 * volumeTile.contentScale
                        height: width
                        radius: width / 2
                        color: index === volumeTile.currentDeviceIdx ? themeManager.accentColor : themeManager.borderColor
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2
                            onClicked: volumeTile.currentDeviceIdx = parent.index
                        }
                    }
                }
            }
        }

        // --- HORIZONTAL LAYOUT ---
        Row {
            anchors.fill: parent
            spacing: 6
            visible: !volumeTile.isVertical

            // Mute button at left (with icon switching)
            Item {
                width: muteRowBtn.width
                height: parent.height
                visible: volumeTile.showMuteBtn

                Rectangle {
                    id: muteRowBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * volumeTile.contentScale
                    height: 32 * volumeTile.contentScale
                    radius: width / 2
                    color: muteRowArea.containsMouse ? themeManager.overlayColor : "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 18 * volumeTile.contentScale
                        height: 18 * volumeTile.contentScale
                        source: volumeTile.activeIcon
                        color: volumeTile.iconColor
                    }

                    MouseArea {
                        id: muteRowArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: volumeTile.toggleMute()
                    }
                }
            }

            // Middle column: device label + slider + dots
            Column {
                width: parent.width
                       - (volumeTile.showMuteBtn ? muteRowBtn.width + 6 : 0)
                       - (volumeTile.showPercent ? volPercentRow.width + 6 : 0)
                height: parent.height
                spacing: 2

                // Device label
                Item {
                    id: deviceLabelH
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: volumeTile.multiDevice && (volumeTile.deviceLabel !== "" || volumeTile.deviceIcon !== "")
                    width: parent.width
                    height: deviceLabelHContent.height

                    Row {
                        id: deviceLabelHContent
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Image {
                            visible: volumeTile.deviceIcon !== "" && (volumeTile.deviceLabelMode === "icon" || volumeTile.deviceLabelMode === "both")
                            source: volumeTile.deviceIcon
                            sourceSize.width: 14 * volumeTile.contentScale
                            sourceSize.height: 14 * volumeTile.contentScale
                            width: 14 * volumeTile.contentScale
                            height: 14 * volumeTile.contentScale
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: volumeTile.deviceAvailable ? 1.0 : 0.3
                        }

                        Text {
                            visible: volumeTile.deviceLabelMode === "text" || volumeTile.deviceLabelMode === "both"
                                     || volumeTile.deviceIcon === ""
                            text: volumeTile.deviceAvailable ? volumeTile.deviceLabel : "Unavailable"
                            color: volumeTile.deviceAvailable ? themeManager.secondaryTextColor : themeManager.errorColor
                            font.pixelSize: 10 * volumeTile.contentScale
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Slider track
                Item {
                    width: parent.width
                    height: parent.height
                           - (volumeTile.multiDevice && volumeTile.deviceLabel !== "" ? deviceLabelH.height + 2 : 0)
                           - (volumeTile.multiDevice && volumeTile.volumeDevices.length > 1 ? dotsH.height + 2 : 0)

                    opacity: volumeTile.deviceAvailable ? 1.0 : 0.3

                    Rectangle {
                        id: hTrack
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: volumeTile.trackThick
                        radius: volumeTile.trackThick / 2
                        color: themeManager.borderColor

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width * Math.min(volumeTile.currentVolume, 1)
                            radius: volumeTile.trackThick / 2
                            color: volumeTile.isMuted ? themeManager.secondaryTextColor : volumeTile.barColor
                        }

                        Rectangle {
                            width: volumeTile.thumbAlong   // swap for horizontal
                            height: volumeTile.thumbCross
                            radius: volumeTile.thumbRadius
                            color: volumeTile.knobColor
                            border.width: 1
                            border.color: themeManager.borderColor
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * Math.min(volumeTile.currentVolume, 1) - width / 2))
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
                        readonly property bool canSwipe: volumeTile.multiDevice && volumeTile.volumeDevices.length > 1

                        onPressed: (mouse) => {
                            pressX = mouse.x; pressY = mouse.y
                            gestureLocked = false; isSwipeGesture = false
                            volumeTile.isSwiping = false
                            if (!canSwipe) { gestureLocked = true; isSwipeGesture = false }
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            if (!gestureLocked) {
                                var dx = Math.abs(mouse.x - pressX)
                                var dy = Math.abs(mouse.y - pressY)
                                if (dx > 15 || dy > 15) {
                                    // Horizontal tile: vertical drag = swipe, horizontal drag = slider
                                    isSwipeGesture = dy > dx
                                    gestureLocked = true
                                    if (isSwipeGesture) volumeTile.isSwiping = true
                                }
                                return  // Don't move slider until gesture is decided
                            }
                            if (!isSwipeGesture) updateHVol(mouse)
                        }
                        onReleased: (mouse) => {
                            if (isSwipeGesture) {
                                var deltaY = pressY - mouse.y
                                if (deltaY > 40) volumeTile.selectNextDevice()
                                else if (deltaY < -40) volumeTile.selectPreviousDevice()
                            } else if (!gestureLocked) {
                                updateHVol(mouse)
                            }
                            volumeTile.isSwiping = false
                        }

                        function updateHVol(mouse) {
                            if (!volumeTile.deviceAvailable) return
                            var trackLeft = hTrack.x
                            var trackW = hTrack.width
                            var percent = (mouse.x - trackLeft) / trackW
                            percent = Math.max(0, Math.min(1, percent))
                            volumeTile.setVolume(Math.round(percent * 100))
                        }
                    }
                }

                // Indicator dots (horizontal tile — at bottom of middle column)
                Row {
                    id: dotsH
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    visible: volumeTile.multiDevice && volumeTile.volumeDevices.length > 1

                    Repeater {
                        model: volumeTile.volumeDevices.length
                        Rectangle {
                            required property int index
                            width: 6 * volumeTile.contentScale
                            height: width
                            radius: width / 2
                            color: index === volumeTile.currentDeviceIdx ? themeManager.accentColor : themeManager.borderColor
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -2
                                onClicked: volumeTile.currentDeviceIdx = parent.index
                            }
                        }
                    }
                }
            }

            // Percent at right
            Text {
                id: volPercentRow
                anchors.verticalCenter: parent.verticalCenter
                visible: volumeTile.showPercent
                text: {
                    var val = Math.round(volumeTile.currentVolume * 100)
                    return val + "%"
                }
                color: volumeTile.isMuted ? themeManager.secondaryTextColor : volumeTile.percentColor
                font.pixelSize: 13 * volumeTile.contentScale
                font.weight: Font.DemiBold
            }
        }

        // Swipe detection is integrated into the slider MouseAreas above
    }
}
