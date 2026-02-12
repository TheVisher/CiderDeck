import QtQuick

Card {
    id: volumeTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    readonly property bool isVertical: height > width

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

        // Simple volume slider placeholder
        // Uses the first sink from AudioManager
        Item {
            width: parent.width
            height: parent.height - (volumeTile.sizeClass !== "tiny" ? 24 : 0)

            Rectangle {
                id: sliderTrack
                anchors.centerIn: parent
                width: volumeTile.isVertical ? 6 : parent.width - 20
                height: volumeTile.isVertical ? parent.height - 20 : 6
                radius: 3
                color: themeManager.borderColor

                Rectangle {
                    width: volumeTile.isVertical ? parent.width : parent.width * 0.75
                    height: volumeTile.isVertical ? parent.height * 0.75 : parent.height
                    radius: 3
                    color: themeManager.accentColor
                    anchors.left: volumeTile.isVertical ? parent.left : undefined
                    anchors.bottom: volumeTile.isVertical ? parent.bottom : undefined
                }
            }

            MouseArea {
                anchors.fill: parent
                onPositionChanged: (mouse) => {
                    // Volume control via drag
                    if (audioManager && audioManager.sinkModel) {
                        let percent
                        if (volumeTile.isVertical) {
                            percent = 100 * (1 - mouse.y / height)
                        } else {
                            percent = 100 * (mouse.x / width)
                        }
                        percent = Math.max(0, Math.min(100, percent))
                        audioManager.setSinkVolume(0, Math.round(percent))
                    }
                }
            }
        }
    }
}
