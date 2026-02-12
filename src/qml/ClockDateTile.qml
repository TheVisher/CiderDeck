import QtQuick

Card {
    id: clockTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    // Clock format settings
    readonly property string timeFormat: settings.timeFormat || "12h"
    readonly property string dateFormat: settings.dateFormat || "ddd, MMM d"
    readonly property bool showSeconds: settings.showSeconds || false

    function formatTime(date) {
        if (timeFormat === "24h") {
            return showSeconds ? Qt.formatTime(date, "HH:mm:ss") : Qt.formatTime(date, "HH:mm")
        } else {
            return showSeconds ? Qt.formatTime(date, "h:mm:ss AP") : Qt.formatTime(date, "h:mm AP")
        }
    }

    function formatDate(date) {
        return Qt.formatDate(date, dateFormat)
    }

    Timer {
        interval: clockTile.showSeconds ? 1000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            timeText.text = clockTile.formatTime(now)
            dateText.text = clockTile.formatDate(now)
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
