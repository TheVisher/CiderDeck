import QtQuick

Card {
    id: clockTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

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
        width: parent.width - 16
        spacing: clockTile.sizeClass === "tiny" ? 0 : 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: themeManager.textColor
            font.pixelSize: {
                var base
                switch (clockTile.sizeClass) {
                case "tiny":  base = Math.min(clockTile.width, clockTile.height) * 0.35; break
                case "small": base = Math.min(clockTile.width, clockTile.height) * 0.3; break
                default:      base = Math.min(clockTile.width, clockTile.height) * 0.25; break
                }
                return base * clockTile.contentScale
            }
            font.weight: Font.DemiBold
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: themeManager.secondaryTextColor
            visible: clockTile.sizeClass !== "tiny"
            font.pixelSize: {
                var base
                switch (clockTile.sizeClass) {
                case "small": base = Math.min(clockTile.width, clockTile.height) * 0.12; break
                default:      base = Math.min(clockTile.width, clockTile.height) * 0.1; break
                }
                return base * clockTile.contentScale
            }
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 8
        }
    }
}
