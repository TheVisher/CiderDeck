import QtQuick

CardButton {
    id: screenshotTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    onClicked: {
        screenshotService.captureScreen(settings.defaultMonitor || "")
    }

    Connections {
        target: screenshotService
        function onScreenshotSaved(path) {
            toastModel.show("Screenshot saved")
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "image://appicon/spectacle"
            sourceSize.width: iconSize
            sourceSize.height: iconSize
            width: iconSize
            height: iconSize

            readonly property int iconSize: {
                var base
                switch (screenshotTile.sizeClass) {
                case "tiny":  base = Math.min(screenshotTile.width, screenshotTile.height) * 0.5; break
                case "small": base = Math.min(screenshotTile.width, screenshotTile.height) * 0.4; break
                default:      base = 40; break
                }
                return base * screenshotTile.contentScale
            }
        }

        Text {
            text: "Screenshot"
            color: themeManager.textColor
            font.pixelSize: 12 * screenshotTile.contentScale
            visible: screenshotTile.sizeClass !== "tiny"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Region select (medium+ only)
        Rectangle {
            width: regionText.width + 16
            height: 28
            radius: 14
            color: themeManager.overlayColor
            visible: screenshotTile.sizeClass === "medium" || screenshotTile.sizeClass === "large"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: regionText
                anchors.centerIn: parent
                text: "Region"
                color: themeManager.textColor
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                onClicked: screenshotService.captureRegion()
            }
        }
    }
}
