import QtQuick

Card {
    id: brightnessTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    readonly property bool isVertical: height > width

    // Decouple visual from async service during drag
    property bool dragging: false
    property real localBrightness: brightnessService.brightness / 100

    // Only sync from service when NOT dragging
    Connections {
        target: brightnessService
        function onBrightnessChanged() {
            if (!brightnessTile.dragging) {
                brightnessTile.localBrightness = brightnessService.brightness / 100
            }
        }
    }

    // Throttle ddcutil calls during drag (max every 200ms)
    Timer {
        id: ddcThrottle
        interval: 200
        property int pendingPercent: -1
        onTriggered: {
            if (pendingPercent >= 0) {
                brightnessService.setBrightness(pendingPercent)
                pendingPercent = -1
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Sun icon + percentage
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: brightnessTile.sizeClass !== "tiny"

            Text {
                text: "\u2600"
                color: themeManager.textColor
                font.pixelSize: 18
            }
            Text {
                text: Math.round(brightnessTile.localBrightness * 100) + "%"
                color: themeManager.textColor
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        // Slider
        Item {
            width: parent.width
            height: parent.height - (brightnessTile.sizeClass !== "tiny" ? 30 : 0)

            Rectangle {
                id: sliderTrack
                anchors.centerIn: parent
                width: brightnessTile.isVertical ? 8 : parent.width - 20
                height: brightnessTile.isVertical ? parent.height - 20 : 8
                radius: 4
                color: themeManager.borderColor

                Rectangle {
                    width: brightnessTile.isVertical ? parent.width
                           : parent.width * brightnessTile.localBrightness
                    height: brightnessTile.isVertical
                            ? parent.height * brightnessTile.localBrightness
                            : parent.height
                    radius: 4
                    color: "#FFD54F"
                    anchors.left: brightnessTile.isVertical ? parent.left : undefined
                    anchors.bottom: brightnessTile.isVertical ? parent.bottom : undefined

                    Behavior on width { enabled: !brightnessTile.dragging; NumberAnimation { duration: 80 } }
                    Behavior on height { enabled: !brightnessTile.dragging; NumberAnimation { duration: 80 } }
                }

                // Thumb indicator
                Rectangle {
                    width: brightnessTile.isVertical ? 20 : 16
                    height: brightnessTile.isVertical ? 16 : 20
                    radius: 8
                    color: "white"
                    border.width: 1
                    border.color: themeManager.borderColor
                    x: brightnessTile.isVertical
                       ? (parent.width - width) / 2
                       : parent.width * brightnessTile.localBrightness - width / 2
                    y: brightnessTile.isVertical
                       ? parent.height * (1 - brightnessTile.localBrightness) - height / 2
                       : (parent.height - height) / 2
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true

                function updateBrightness(mouse) {
                    let percent
                    if (brightnessTile.isVertical) {
                        let trackTop = sliderTrack.y
                        let trackH = sliderTrack.height
                        percent = 1 - ((mouse.y - trackTop) / trackH)
                    } else {
                        let trackLeft = sliderTrack.x
                        let trackW = sliderTrack.width
                        percent = (mouse.x - trackLeft) / trackW
                    }
                    percent = Math.max(0.01, Math.min(1, percent))
                    brightnessTile.localBrightness = percent

                    // Throttle ddcutil calls
                    let intPercent = Math.round(percent * 100)
                    if (!ddcThrottle.running) {
                        brightnessService.setBrightness(intPercent)
                        ddcThrottle.start()
                    } else {
                        ddcThrottle.pendingPercent = intPercent
                    }
                }

                onPressed: (mouse) => {
                    brightnessTile.dragging = true
                    updateBrightness(mouse)
                }
                onPositionChanged: (mouse) => {
                    if (pressed) updateBrightness(mouse)
                }
                onReleased: {
                    brightnessTile.dragging = false
                    // Send final value
                    let intPercent = Math.round(brightnessTile.localBrightness * 100)
                    brightnessService.setBrightness(intPercent)
                }
                onCanceled: {
                    brightnessTile.dragging = false
                }
            }
        }
    }
}
