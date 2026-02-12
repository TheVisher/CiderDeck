import QtQuick

Card {
    id: volumeTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property bool isVertical: height > width
    readonly property real currentVolume: audioManager ? audioManager.defaultVolume / 100 : 0.75
    readonly property bool isMuted: audioManager ? audioManager.defaultMuted : false
    readonly property bool showPercent: settings.showPercent !== false
    readonly property bool showMuteBtn: settings.showMuteBtn !== false

    // Vertical layout: mute at top, slider in middle, percent at bottom
    // Horizontal layout: mute at left, slider in middle, percent at right
    Item {
        anchors.fill: parent
        anchors.margins: 8

        // --- VERTICAL LAYOUT ---
        Column {
            anchors.fill: parent
            spacing: 4
            visible: volumeTile.isVertical

            // Mute button at top
            Item {
                width: parent.width
                height: muteColBtn.height
                visible: volumeTile.showMuteBtn

                Rectangle {
                    id: muteColBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32 * volumeTile.contentScale
                    height: 32 * volumeTile.contentScale
                    radius: width / 2
                    color: muteColArea.containsMouse ? themeManager.overlayColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: volumeTile.isMuted ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                        font.pixelSize: 16 * volumeTile.contentScale
                    }

                    MouseArea {
                        id: muteColArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: {
                            if (audioManager) audioManager.setDefaultMuted(!volumeTile.isMuted)
                        }
                    }
                }
            }

            // Slider track (fills remaining space)
            Item {
                width: parent.width
                height: parent.height
                       - (volumeTile.showMuteBtn ? muteColBtn.height + 4 : 0)
                       - (volumeTile.showPercent ? volPercentCol.height + 4 : 0)

                Rectangle {
                    id: vTrack
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 8
                    radius: 4
                    color: themeManager.borderColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.min(volumeTile.currentVolume, 1)
                        radius: 4
                        color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.accentColor
                    }

                    Rectangle {
                        width: 20
                        height: 16
                        radius: 8
                        color: "white"
                        border.width: 1
                        border.color: themeManager.borderColor
                        x: (parent.width - width) / 2
                        y: parent.height * (1 - Math.min(volumeTile.currentVolume, 1)) - height / 2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: (mouse) => updateVol(mouse)
                    onPositionChanged: (mouse) => { if (pressed) updateVol(mouse) }

                    function updateVol(mouse) {
                        var trackTop = vTrack.y
                        var trackH = vTrack.height
                        var percent = 1 - ((mouse.y - trackTop) / trackH)
                        percent = Math.max(0, Math.min(1, percent))
                        if (audioManager) audioManager.setDefaultVolume(Math.round(percent * 100))
                    }
                }
            }

            // Percent at bottom
            Text {
                id: volPercentCol
                anchors.horizontalCenter: parent.horizontalCenter
                visible: volumeTile.showPercent
                text: {
                    var val = Math.round(volumeTile.currentVolume * 100)
                    return val + "%"
                }
                color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.textColor
                font.pixelSize: 13 * volumeTile.contentScale
                font.weight: Font.DemiBold
            }
        }

        // --- HORIZONTAL LAYOUT ---
        Row {
            anchors.fill: parent
            spacing: 6
            visible: !volumeTile.isVertical

            // Mute button at left
            Item {
                width: muteRowBtn.width
                height: parent.height
                visible: volumeTile.showMuteBtn

                Rectangle {
                    id: muteRowBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * volumeTile.contentScale
                    height: 32 * volumeTile.contentScale
                    radius: width / 2
                    color: muteRowArea.containsMouse ? themeManager.overlayColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: volumeTile.isMuted ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                        font.pixelSize: 16 * volumeTile.contentScale
                    }

                    MouseArea {
                        id: muteRowArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: {
                            if (audioManager) audioManager.setDefaultMuted(!volumeTile.isMuted)
                        }
                    }
                }
            }

            // Slider track (fills remaining space)
            Item {
                width: parent.width
                       - (volumeTile.showMuteBtn ? muteRowBtn.width + 6 : 0)
                       - (volumeTile.showPercent ? volPercentRow.width + 6 : 0)
                height: parent.height

                Rectangle {
                    id: hTrack
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 8
                    radius: 4
                    color: themeManager.borderColor

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width * Math.min(volumeTile.currentVolume, 1)
                        radius: 4
                        color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.accentColor
                    }

                    Rectangle {
                        width: 16
                        height: 20
                        radius: 8
                        color: "white"
                        border.width: 1
                        border.color: themeManager.borderColor
                        x: parent.width * Math.min(volumeTile.currentVolume, 1) - width / 2
                        y: (parent.height - height) / 2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: (mouse) => updateHVol(mouse)
                    onPositionChanged: (mouse) => { if (pressed) updateHVol(mouse) }

                    function updateHVol(mouse) {
                        var trackLeft = hTrack.x
                        var trackW = hTrack.width
                        var percent = (mouse.x - trackLeft) / trackW
                        percent = Math.max(0, Math.min(1, percent))
                        if (audioManager) audioManager.setDefaultVolume(Math.round(percent * 100))
                    }
                }
            }

            // Percent at right
            Text {
                id: volPercentRow
                anchors.verticalCenter: parent.verticalCenter
                visible: volumeTile.showPercent
                text: {
                    var val = Math.round(volumeTile.currentVolume * 100)
                    return val + "%"
                }
                color: volumeTile.isMuted ? themeManager.secondaryTextColor : themeManager.textColor
                font.pixelSize: 13 * volumeTile.contentScale
                font.weight: Font.DemiBold
            }
        }
    }
}
