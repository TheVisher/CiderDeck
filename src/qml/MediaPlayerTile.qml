import QtQuick

Card {
    id: mediaTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Album art background (dimmed)
    Image {
        anchors.fill: parent
        source: mprisManager.artUrl || ""
        fillMode: Image.PreserveAspectCrop
        opacity: 0.3
        visible: source !== "" && mediaTile.sizeClass !== "tiny"
    }

    // Dimming overlay on background art
    Rectangle {
        anchors.fill: parent
        radius: mediaTile.radius
        color: Qt.rgba(themeManager.backgroundColor.r,
                       themeManager.backgroundColor.g,
                       themeManager.backgroundColor.b, 0.5)
        visible: mprisManager.artUrl !== "" && mediaTile.sizeClass !== "tiny"
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

    // Small: transport controls only (centered, large buttons)
    Row {
        anchors.centerIn: parent
        spacing: Math.min(parent.width * 0.12, 32)
        visible: mediaTile.sizeClass === "small"

        Text {
            text: "\u23EE"
            color: themeManager.textColor
            font.pixelSize: 36
            verticalAlignment: Text.AlignVCenter
            height: 48
            opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: mprisManager.previous()
            }
        }
        Text {
            text: mprisManager.playbackStatus === "Playing" ? "\u23F8" : "\u25B6"
            color: themeManager.textColor
            font.pixelSize: 48
            verticalAlignment: Text.AlignVCenter
            height: 48
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: mprisManager.playPause()
            }
        }
        Text {
            text: "\u23ED"
            color: themeManager.textColor
            font.pixelSize: 36
            verticalAlignment: Text.AlignVCenter
            height: 48
            opacity: mprisManager.canGoNext ? 1.0 : 0.3
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: mprisManager.next()
            }
        }
    }

    // Medium/Large: info at top, controls at bottom
    Item {
        anchors.fill: parent
        anchors.margins: 12
        visible: mediaTile.sizeClass === "medium" || mediaTile.sizeClass === "large"

        // Top: Album art + info
        Row {
            id: infoRow
            anchors.top: parent.top
            width: parent.width
            spacing: 12

            Image {
                id: albumArt
                width: mediaTile.sizeClass === "large" ? 80 : 56
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
                width: parent.width - (albumArt.visible ? albumArt.width + 12 : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: mprisManager.title || "No track"
                    color: themeManager.textColor
                    font.pixelSize: 15 * mediaTile.contentScale
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: mprisManager.artist || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 13 * mediaTile.contentScale
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== ""
                }
                Text {
                    text: mprisManager.album || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 11 * mediaTile.contentScale
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== "" && mediaTile.sizeClass === "large"
                }
            }
        }

        // Progress bar
        Item {
            id: progressBar
            anchors.bottom: transportRow.top
            anchors.bottomMargin: 8
            width: parent.width
            height: 16
            visible: mprisManager.duration > 0

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

        // Bottom: Transport controls — large and spread out
        Row {
            id: transportRow
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.min(parent.width * 0.15, 48)

            Text {
                text: "\u23EE"
                color: themeManager.textColor
                font.pixelSize: 36
                verticalAlignment: Text.AlignVCenter
                height: 48
                opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    onClicked: mprisManager.previous()
                }
            }
            Text {
                text: mprisManager.playbackStatus === "Playing" ? "\u23F8" : "\u25B6"
                color: themeManager.textColor
                font.pixelSize: 48
                verticalAlignment: Text.AlignVCenter
                height: 48
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    onClicked: mprisManager.playPause()
                }
            }
            Text {
                text: "\u23ED"
                color: themeManager.textColor
                font.pixelSize: 36
                verticalAlignment: Text.AlignVCenter
                height: 48
                opacity: mprisManager.canGoNext ? 1.0 : 0.3
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    onClicked: mprisManager.next()
                }
            }
        }
    }
}
