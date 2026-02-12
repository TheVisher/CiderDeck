import QtQuick

CardButton {
    id: screenshotTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

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
                switch (screenshotTile.sizeClass) {
                case "tiny":  return Math.min(screenshotTile.width, screenshotTile.height) * 0.5
                case "small": return Math.min(screenshotTile.width, screenshotTile.height) * 0.4
                default:      return 40
                }
            }
        }

        Text {
            text: "Screenshot"
            color: themeManager.textColor
            font.pixelSize: 12
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
