import QtQuick

Card {
    id: mediaTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    // Album art background (dimmed)
    Image {
        anchors.fill: parent
        source: mprisManager.artUrl || ""
        fillMode: Image.PreserveAspectCrop
        opacity: 0.2
        visible: source !== "" && mediaTile.sizeClass !== "tiny"

        Rectangle {
            anchors.fill: parent
            radius: mediaTile.radius
            color: Qt.rgba(themeManager.backgroundColor.r,
                           themeManager.backgroundColor.g,
                           themeManager.backgroundColor.b, 0.6)
        }
    }

    // Tiny: just play/pause button
    Item {
        anchors.fill: parent
        visible: mediaTile.sizeClass === "tiny"

        Text {
            anchors.centerIn: parent
            text: mprisManager.playbackStatus === "Playing" ? "\u23F8" : "\u25B6"
            color: themeManager.textColor
            font.pixelSize: Math.min(parent.width, parent.height) * 0.4

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                onClicked: mprisManager.playPause()
            }
        }
    }

    // Small: transport controls
    Row {
        anchors.centerIn: parent
        spacing: 16
        visible: mediaTile.sizeClass === "small"

        Text {
            text: "\u23EE"
            color: themeManager.textColor
            font.pixelSize: 20
            opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
            MouseArea { anchors.fill: parent; onClicked: mprisManager.previous() }
        }
        Text {
            text: mprisManager.playbackStatus === "Playing" ? "\u23F8" : "\u25B6"
            color: themeManager.textColor
            font.pixelSize: 28
            MouseArea { anchors.fill: parent; onClicked: mprisManager.playPause() }
        }
        Text {
            text: "\u23ED"
            color: themeManager.textColor
            font.pixelSize: 20
            opacity: mprisManager.canGoNext ? 1.0 : 0.3
            MouseArea { anchors.fill: parent; onClicked: mprisManager.next() }
        }
    }

    // Medium/Large: full player
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        visible: mediaTile.sizeClass === "medium" || mediaTile.sizeClass === "large"

        // Album art + info row
        Row {
            width: parent.width
            spacing: 12

            Image {
                id: albumArt
                width: mediaTile.sizeClass === "large" ? 80 : 48
                height: width
                source: mprisManager.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                visible: source !== ""

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: themeManager.borderColor
                }
            }

            Column {
                width: parent.width - albumArt.width - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: mprisManager.title || "No track"
                    color: themeManager.textColor
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: mprisManager.artist || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== ""
                }
                Text {
                    text: mprisManager.album || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== "" && mediaTile.sizeClass === "large"
                }
            }
        }

        // Progress bar (large only)
        Item {
            width: parent.width
            height: 20
            visible: mediaTile.sizeClass === "large" && mprisManager.duration > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: themeManager.borderColor

                Rectangle {
                    width: mprisManager.duration > 0
                           ? parent.width * (mprisManager.position / mprisManager.duration)
                           : 0
                    height: parent.height
                    radius: 2
                    color: themeManager.accentColor
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    if (mprisManager.duration > 0 && mprisManager.canSeek) {
                        let pos = (mouse.x / width) * mprisManager.duration
                        mprisManager.setPosition(pos)
                    }
                }
            }
        }

        // Transport controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Text {
                text: "\u23EE"
                color: themeManager.textColor
                font.pixelSize: 22
                opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
                MouseArea { anchors.fill: parent; onClicked: mprisManager.previous() }
            }
            Text {
                text: mprisManager.playbackStatus === "Playing" ? "\u23F8" : "\u25B6"
                color: themeManager.textColor
                font.pixelSize: 30
                MouseArea { anchors.fill: parent; onClicked: mprisManager.playPause() }
            }
            Text {
                text: "\u23ED"
                color: themeManager.textColor
                font.pixelSize: 22
                opacity: mprisManager.canGoNext ? 1.0 : 0.3
                MouseArea { anchors.fill: parent; onClicked: mprisManager.next() }
            }
        }
    }
}
