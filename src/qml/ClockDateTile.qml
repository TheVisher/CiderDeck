import QtQuick

Card {
    id: clockTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            timeText.text = Qt.formatTime(new Date(), "h:mm")
            dateText.text = Qt.formatDate(new Date(), "ddd, MMM d")
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: clockTile.sizeClass === "tiny" ? 0 : 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: themeManager.textColor
            font.pixelSize: {
                switch (clockTile.sizeClass) {
                case "tiny":  return Math.min(clockTile.width, clockTile.height) * 0.35
                case "small": return Math.min(clockTile.width, clockTile.height) * 0.3
                default:      return Math.min(clockTile.width, clockTile.height) * 0.25
                }
            }
            font.weight: Font.DemiBold
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: themeManager.secondaryTextColor
            visible: clockTile.sizeClass !== "tiny"
            font.pixelSize: {
                switch (clockTile.sizeClass) {
                case "small": return Math.min(clockTile.width, clockTile.height) * 0.12
                default:      return Math.min(clockTile.width, clockTile.height) * 0.1
                }
            }
        }
    }
}
