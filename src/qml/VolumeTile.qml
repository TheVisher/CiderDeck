import QtQuick

Card {
    id: volumeTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    readonly property bool isVertical: height > width
    // Read from the actual default sink volume (0-100+)
    readonly property real currentVolume: audioManager ? audioManager.defaultVolume / 100 : 0.75
    readonly property bool isMuted: audioManager ? audioManager.defaultMuted : false

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header row: icon + label + percentage
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: volumeTile.sizeClass !== "tiny"

            Text {
                text: volumeTile.isMuted ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                color: themeManager.textColor
                font.pixelSize: 16

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: {
                        if (audioManager) audioManager.setDefaultMuted(!volumeTile.isMuted)
                    }
                }
            }

            Text {
                text: Math.round(volumeTile.currentVolume * 100) + "%"
                color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.textColor
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        Item {
            width: parent.width
            height: parent.height - (volumeTile.sizeClass !== "tiny" ? 36 : 0)

            Rectangle {
                id: sliderTrack
                anchors.centerIn: parent
                width: volumeTile.isVertical ? 8 : parent.width - 20
                height: volumeTile.isVertical ? parent.height - 20 : 8
                radius: 4
                color: themeManager.borderColor

                Rectangle {
                    width: volumeTile.isVertical ? parent.width
                           : parent.width * Math.min(volumeTile.currentVolume, 1)
                    height: volumeTile.isVertical
                            ? parent.height * Math.min(volumeTile.currentVolume, 1)
                            : parent.height
                    radius: 4
                    color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.accentColor
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
                       : parent.width * Math.min(volumeTile.currentVolume, 1) - width / 2
                    y: volumeTile.isVertical
                       ? parent.height * (1 - Math.min(volumeTile.currentVolume, 1)) - height / 2
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

                    if (audioManager) {
                        audioManager.setDefaultVolume(Math.round(percent * 100))
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
