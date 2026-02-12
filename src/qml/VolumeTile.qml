import QtQuick

Card {
    id: volumeTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    readonly property bool isVertical: height > width
    property real currentVolume: 0.75

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Text {
            text: "Volume"
            color: themeManager.textColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            visible: volumeTile.sizeClass !== "tiny"
        }

        Text {
            text: Math.round(volumeTile.currentVolume * 100) + "%"
            color: themeManager.secondaryTextColor
            font.pixelSize: 11
            visible: volumeTile.sizeClass !== "tiny"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item {
            width: parent.width
            height: parent.height - (volumeTile.sizeClass !== "tiny" ? 44 : 0)

            Rectangle {
                id: sliderTrack
                anchors.centerIn: parent
                width: volumeTile.isVertical ? 8 : parent.width - 20
                height: volumeTile.isVertical ? parent.height - 20 : 8
                radius: 4
                color: themeManager.borderColor

                Rectangle {
                    width: volumeTile.isVertical ? parent.width : parent.width * volumeTile.currentVolume
                    height: volumeTile.isVertical ? parent.height * volumeTile.currentVolume : parent.height
                    radius: 4
                    color: themeManager.accentColor
                    anchors.left: volumeTile.isVertical ? parent.left : undefined
                    anchors.bottom: volumeTile.isVertical ? parent.bottom : undefined
                }

                // Thumb indicator
                Rectangle {
                    width: volumeTile.isVertical ? 20 : 16
                    height: volumeTile.isVertical ? 16 : 20
                    radius: 8
                    color: "white"
                    border.width: 1
                    border.color: themeManager.borderColor
                    x: volumeTile.isVertical
                       ? (parent.width - width) / 2
                       : parent.width * volumeTile.currentVolume - width / 2
                    y: volumeTile.isVertical
                       ? parent.height * (1 - volumeTile.currentVolume) - height / 2
                       : (parent.height - height) / 2
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true

                function updateVolume(mouse) {
                    let percent
                    if (volumeTile.isVertical) {
                        let trackTop = sliderTrack.y
                        let trackH = sliderTrack.height
                        percent = 1 - ((mouse.y - trackTop) / trackH)
                    } else {
                        let trackLeft = sliderTrack.x
                        let trackW = sliderTrack.width
                        percent = (mouse.x - trackLeft) / trackW
                    }
                    percent = Math.max(0, Math.min(1, percent))
                    volumeTile.currentVolume = percent

                    if (audioManager) {
                        audioManager.setSinkVolume(0, Math.round(percent * 100))
                    }
                }

                onPressed: (mouse) => updateVolume(mouse)
                onPositionChanged: (mouse) => {
                    if (pressed) updateVolume(mouse)
                }
            }
        }
    }
}
