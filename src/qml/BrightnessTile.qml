import QtQuick

Card {
    id: brightnessTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    readonly property bool isVertical: height > width

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
                text: brightnessService.brightness + "%"
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
                anchors.centerIn: parent
                width: brightnessTile.isVertical ? 6 : parent.width - 20
                height: brightnessTile.isVertical ? parent.height - 20 : 6
                radius: 3
                color: themeManager.borderColor

                Rectangle {
                    width: brightnessTile.isVertical ? parent.width
                           : parent.width * (brightnessService.brightness / 100)
                    height: brightnessTile.isVertical
                            ? parent.height * (brightnessService.brightness / 100)
                            : parent.height
                    radius: 3
                    color: "#FFD54F"
                    anchors.left: brightnessTile.isVertical ? parent.left : undefined
                    anchors.bottom: brightnessTile.isVertical ? parent.bottom : undefined
                }
            }

            MouseArea {
                anchors.fill: parent
                onPositionChanged: (mouse) => {
                    let percent
                    if (brightnessTile.isVertical) {
                        percent = 100 * (1 - mouse.y / height)
                    } else {
                        percent = 100 * (mouse.x / width)
                    }
                    brightnessService.setBrightness(Math.round(Math.max(1, Math.min(100, percent))))
                }
            }
        }
    }
}
