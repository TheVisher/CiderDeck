import QtQuick

Card {
    id: mixerTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Own layout mode — ignores sizeClass for orientation decisions.
    // Vertical slider whenever the tile is portrait or square.
    // Horizontal bar only when clearly landscape AND small.
    readonly property string layoutMode: {
        if (width < 70 && height < 70) return "tiny"
        if (sizeClass === "tiny") return "tiny"
        if (height >= width) return "vertical"
        // Landscape: use horizontal bar if compact, vertical if large
        if (width > 300 && height > 200) return "vertical"
        return "horizontal"
    }

    // Primary group selection
    readonly property int primaryGroupIdx: settings.primaryGroup || 0
    readonly property var groupList: audioMixerService ? audioMixerService.groups : []
    readonly property var grp: groupList[primaryGroupIdx] || ({})
    readonly property bool isGen: grp.isGeneral || false
    readonly property int _audioTick: audioManager ? audioManager.refreshTick : 0
    readonly property int vol: {
        void(_audioTick)
        if (isGen) return audioManager ? audioManager.defaultVolume : 0
        // Read live volume from first active app stream
        if (audioManager) {
            var apps = grp.apps || []
            for (var i = 0; i < apps.length; i++) {
                var streams = audioManager.findStreamsByApp(apps[i])
                if (streams.length > 0) return audioManager.appVolume(apps[i])
            }
        }
        return grp.volume || 0
    }
    readonly property bool muted: {
        void(_audioTick)
        if (isGen) return audioManager ? audioManager.defaultMuted : false
        if (audioManager) {
            var apps = grp.apps || []
            for (var i = 0; i < apps.length; i++) {
                var streams = audioManager.findStreamsByApp(apps[i])
                if (streams.length > 0) return audioManager.appMuted(apps[i])
            }
        }
        return grp.muted || false
    }
    readonly property string groupName: grp.name || "General"

    // Slider appearance
    readonly property real sliderScale: settings.sliderThickness || 1.0
    readonly property real trackThick: 8 * sliderScale
    readonly property real knobScale: settings.knobSize || 1.0
    readonly property real knobBase: trackThick + 12 * knobScale
    readonly property string knobShape: settings.knobShape || "pill"
    readonly property real thumbCross: knobShape === "square" ? knobBase * 0.85 : knobBase
    readonly property real thumbAlong: knobShape === "circle" ? knobBase
        : knobShape === "square" ? knobBase * 0.85
        : Math.max(knobBase * 0.55, 8)
    readonly property real thumbRadius: knobShape === "circle" ? knobBase / 2
        : knobShape === "square" ? 3
        : thumbAlong / 2

    readonly property color barColor: settings.barColor || themeManager.accentColor
    readonly property color knobColor: settings.knobColor || "white"
    readonly property color percentColor: settings.percentColor || themeManager.textColor
    readonly property color iconColor: settings.iconColor || themeManager.textColor

    function setVolume(pct) {
        pct = Math.round(Math.max(0, Math.min(100, pct)))
        if (isGen) {
            audioManager.setDefaultVolume(pct)
        } else {
            audioMixerService.setGroupVolume(primaryGroupIdx, pct)
        }
    }

    function toggleMute() {
        if (isGen) {
            audioManager.setDefaultMuted(!muted)
        } else {
            audioMixerService.setGroupMuted(primaryGroupIdx, !muted)
        }
    }

    // ─── TINY: just an icon, tap opens overlay ───
    Item {
        anchors.fill: parent
        visible: mixerTile.layoutMode === "tiny"

        LucideIcon {
            anchors.centerIn: parent
            width: 22 * mixerTile.contentScale
            height: 22 * mixerTile.contentScale
            source: "qrc:/icons/lucide/sliders-horizontal.svg"
            color: mixerTile.iconColor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mixerOverlay.open(mixerTile.settings)
        }
    }

    // ─── HORIZONTAL: group name + horizontal bar + percentage (landscape compact) ───
    Item {
        anchors.fill: parent
        anchors.margins: 6
        visible: mixerTile.layoutMode === "horizontal"

        Column {
            anchors.fill: parent
            spacing: 4

            // Group name
            Text {
                width: parent.width
                text: mixerTile.groupName
                color: themeManager.secondaryTextColor
                font.pixelSize: 10 * mixerTile.contentScale
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // Horizontal bar + percentage
            Item {
                width: parent.width
                height: Math.max(20 * mixerTile.contentScale, 16)

                Rectangle {
                    id: smallTrack
                    anchors.left: parent.left
                    anchors.right: smallPct.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6 * mixerTile.sliderScale
                    radius: height / 2
                    color: themeManager.borderColor

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width * Math.min(mixerTile.vol / 100, 1)
                        radius: parent.radius
                        color: mixerTile.muted ? themeManager.secondaryTextColor : mixerTile.barColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        preventStealing: true
                        onPressed: (mouse) => updateSmallVol(mouse)
                        onPositionChanged: (mouse) => { if (pressed) updateSmallVol(mouse) }

                        function updateSmallVol(mouse) {
                            var pct = Math.max(0, Math.min(1, mouse.x / smallTrack.width)) * 100
                            mixerTile.setVolume(pct)
                        }
                    }
                }

                Text {
                    id: smallPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: mixerTile.vol + "%"
                    color: mixerTile.muted ? themeManager.secondaryTextColor : mixerTile.percentColor
                    font.pixelSize: 10 * mixerTile.contentScale
                    width: 30 * mixerTile.contentScale
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Expand — small maximize icon centered
            Item {
                width: parent.width
                height: parent.height - parent.spacing * 2 - 14 * mixerTile.contentScale - Math.max(20 * mixerTile.contentScale, 16)
                visible: height > 16

                Rectangle {
                    anchors.centerIn: parent
                    width: 22 * mixerTile.contentScale
                    height: 22 * mixerTile.contentScale
                    radius: 4
                    color: hzExpandMa.containsMouse ? themeManager.overlayColor : "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 12 * mixerTile.contentScale
                        height: 12 * mixerTile.contentScale
                        source: "qrc:/icons/lucide/maximize-2.svg"
                        color: themeManager.secondaryTextColor
                    }

                    MouseArea {
                        id: hzExpandMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: mixerOverlay.open(mixerTile.settings)
                    }
                }
            }
        }
    }

    // ─── VERTICAL: group name → mute → vertical slider → percentage → expand ───
    Item {
        anchors.fill: parent
        anchors.margins: 8
        visible: mixerTile.layoutMode === "vertical"

        Column {
            anchors.fill: parent
            spacing: 2

            // Group name
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mixerTile.groupName
                color: themeManager.textColor
                font.pixelSize: 10 * mixerTile.contentScale
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            // Mute button
            Item {
                width: parent.width
                height: medMuteBtn.height

                Rectangle {
                    id: medMuteBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24 * mixerTile.contentScale
                    height: 24 * mixerTile.contentScale
                    radius: width / 2
                    color: medMuteArea.containsMouse ? themeManager.overlayColor : "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 14 * mixerTile.contentScale
                        height: 14 * mixerTile.contentScale
                        source: mixerTile.muted ? "qrc:/icons/lucide/volume-x.svg"
                                                : "qrc:/icons/lucide/volume-2.svg"
                        color: mixerTile.iconColor
                    }

                    MouseArea {
                        id: medMuteArea
                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        onClicked: mixerTile.toggleMute()
                    }
                }
            }

            // Vertical slider
            Item {
                id: medSliderArea
                width: parent.width
                height: parent.height
                       - 12 * mixerTile.contentScale - 2  // name
                       - medMuteBtn.height - 2             // mute
                       - medPctText.height - 2             // percent
                       - expandIcon.height                  // expand

                Rectangle {
                    id: medTrack
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: mixerTile.trackThick
                    radius: width / 2
                    color: themeManager.borderColor

                    // Fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.min(mixerTile.vol / 100, 1)
                        radius: parent.radius
                        color: mixerTile.muted ? themeManager.secondaryTextColor : mixerTile.barColor
                    }

                    // Knob
                    Rectangle {
                        width: mixerTile.thumbCross
                        height: mixerTile.thumbAlong
                        radius: mixerTile.thumbRadius
                        color: mixerTile.knobColor
                        border.width: 1
                        border.color: themeManager.borderColor
                        x: (parent.width - width) / 2
                        y: Math.max(0, Math.min(parent.height - height,
                            parent.height * (1 - Math.min(mixerTile.vol / 100, 1)) - height / 2))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: (mouse) => updateMedVol(mouse)
                    onPositionChanged: (mouse) => { if (pressed) updateMedVol(mouse) }

                    function updateMedVol(mouse) {
                        var trackTop = medTrack.y
                        var trackH = medTrack.height
                        var pct = 1 - ((mouse.y - trackTop) / trackH)
                        pct = Math.max(0, Math.min(1, pct)) * 100
                        mixerTile.setVolume(pct)
                    }
                }
            }

            // Percentage
            Text {
                id: medPctText
                anchors.horizontalCenter: parent.horizontalCenter
                text: mixerTile.vol + "%"
                color: mixerTile.muted ? themeManager.secondaryTextColor : mixerTile.percentColor
                font.pixelSize: 11 * mixerTile.contentScale
                font.weight: Font.DemiBold
            }

            // Expand — small maximize icon
            Item {
                id: expandIcon
                width: parent.width
                height: 22 * mixerTile.contentScale

                Rectangle {
                    anchors.centerIn: parent
                    width: 22 * mixerTile.contentScale
                    height: 22 * mixerTile.contentScale
                    radius: 4
                    color: expandMa.containsMouse ? themeManager.overlayColor : "transparent"

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 12 * mixerTile.contentScale
                        height: 12 * mixerTile.contentScale
                        source: "qrc:/icons/lucide/maximize-2.svg"
                        color: expandMa.containsMouse ? themeManager.textColor : themeManager.secondaryTextColor
                    }

                    MouseArea {
                        id: expandMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: mixerOverlay.open(mixerTile.settings)
                    }
                }
            }
        }
    }
}
