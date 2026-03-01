import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: mixerOverlay

    anchors.fill: parent
    visible: false

    property var overlaySettings: ({})

    // Resolved settings with defaults
    readonly property string eqPosition: overlaySettings.eqPosition || "left"
    readonly property bool showMic: overlaySettings.showMic !== false
    readonly property bool showEq: (overlaySettings.showEq !== false) && audioMixerService.eqAvailable

    // Slider appearance (from tile settings)
    readonly property real sliderScale: overlaySettings.sliderThickness || 1.0
    readonly property real trackThick: 8 * sliderScale
    readonly property real knobScale: overlaySettings.knobSize || 1.0
    readonly property real knobBase: trackThick + 12 * knobScale
    readonly property string knobShape: overlaySettings.knobShape || "pill"
    readonly property real thumbCross: knobShape === "square" ? knobBase * 0.85 : knobBase
    readonly property real thumbAlong: knobShape === "circle" ? knobBase
        : knobShape === "square" ? knobBase * 0.85
        : Math.max(knobBase * 0.55, 8)
    readonly property real thumbRadius: knobShape === "circle" ? knobBase / 2
        : knobShape === "square" ? 3
        : thumbAlong / 2

    readonly property color barColor: overlaySettings.barColor || themeManager.accentColor
    readonly property color knobColor: overlaySettings.knobColor || "white"
    readonly property color percentColor: overlaySettings.percentColor || themeManager.textColor
    readonly property color iconColor: overlaySettings.iconColor || themeManager.textColor

    // Data from services
    readonly property int _audioTick: audioManager ? audioManager.refreshTick : 0
    readonly property var groupList: audioMixerService ? audioMixerService.groups : []
    readonly property int groupCount: groupList.length
    readonly property int generalVolume: audioManager ? audioManager.defaultVolume : 100
    readonly property bool generalMuted: audioManager ? audioManager.defaultMuted : false
    readonly property var unassignedAppList: {
        void(_audioTick)
        return audioMixerService ? audioMixerService.unassignedApps() : []
    }

    // Reassign state
    property string reassignAppName: ""
    property bool reassignVisible: false

    // Drag state — tracks which group column the drag cursor is over
    property int dragTargetGroup: -1

    function updateDragTarget(panelX) {
        // Map panelX to a group index based on the slider area columns
        var sliderGlobal = sliderArea.mapToItem(panel, 0, 0)
        var relX = panelX - sliderGlobal.x
        if (relX < 0 || relX > sliderArea.width) {
            dragTargetGroup = -1
            return
        }
        var colWidth = sliderArea.width / Math.max(groupCount, 1)
        var idx = Math.floor(relX / colWidth)
        dragTargetGroup = Math.max(0, Math.min(groupCount - 1, idx))
    }

    // App icon tile size
    readonly property real appTileSize: 40

    function open(tileSettings) {
        overlaySettings = tileSettings || {}
        // Sync stored group volumes from actual PulseAudio state
        // so sliders don't jump when grabbed
        audioMixerService.syncGroupVolumes()
        blurSource.scheduleUpdate()
        openTimer.start()
    }

    function close() {
        reassignVisible = false
        visible = false
    }

    // Delay showing by one frame so blur snapshot captures clean scene
    Timer {
        id: openTimer
        interval: 16
        onTriggered: mixerOverlay.visible = true
    }

    // ─── Blurred backdrop ───
    Item {
        anchors.fill: parent

        ShaderEffectSource {
            id: blurSource
            anchors.fill: parent
            sourceItem: dashboard
            live: false
            visible: false
        }

        FastBlur {
            anchors.fill: parent
            source: blurSource
            radius: 96
        }

        // Second blur pass for extra acrylic density
        FastBlur {
            anchors.fill: parent
            source: blurSource
            radius: 96
        }

        // Dark tint over blur
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.65)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mixerOverlay.close()
        }
    }

    // ─── Panel ───
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: parent.width * 0.85
        height: parent.height * 0.90
        radius: 16
        color: themeManager.backgroundColor
        border.width: 1
        border.color: themeManager.borderColor

        // Eat clicks so they don't reach the backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {} // swallow
        }

        // Close button
        Rectangle {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 28
            height: 28
            radius: 14
            color: closeMa.containsMouse ? themeManager.overlayColor : "transparent"
            z: 10

            LucideIcon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: "qrc:/icons/lucide/x.svg"
                color: themeManager.textColor
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mixerOverlay.close()
            }
        }

        // Main layout row — flips EQ to left or right via layoutDirection
        Row {
            id: mainRow
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 20
            spacing: 0
            layoutDirection: mixerOverlay.eqPosition === "right" ? Qt.RightToLeft : Qt.LeftToRight

            // ─── EQ Column ───
            Item {
                id: eqColumn
                visible: mixerOverlay.showEq
                width: visible ? 120 : 0
                height: parent.height

                Column {
                    anchors.fill: parent
                    spacing: 6

                    Text {
                        text: "Output EQ"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Repeater {
                        model: audioMixerService ? audioMixerService.eqPresets : []

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: parent.width - 8
                            height: 30
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: height / 2
                            color: modelData === audioMixerService.currentEqPreset
                                   ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.25)
                                   : Qt.rgba(themeManager.textColor.r, themeManager.textColor.g, themeManager.textColor.b, 0.06)
                            border.width: modelData === audioMixerService.currentEqPreset ? 1 : 0
                            border.color: themeManager.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: modelData === audioMixerService.currentEqPreset
                                       ? themeManager.accentColor : themeManager.textColor
                                font.pixelSize: 11
                                font.weight: modelData === audioMixerService.currentEqPreset
                                             ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width - 16
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: audioMixerService.loadEqPreset(modelData)
                            }
                        }
                    }
                }
            }

            // ─── Separator after EQ ───
            Rectangle {
                visible: eqColumn.visible
                width: 1
                height: parent.height * 0.85
                anchors.verticalCenter: parent.verticalCenter
                color: themeManager.borderColor
            }

            // ─── Slider area (groups) ───
            Item {
                id: sliderArea
                width: parent.width
                       - (eqColumn.visible ? eqColumn.width + 1 : 0)
                       - (micColumn.visible ? micColumn.width + 1 : 0)
                height: parent.height

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: mixerOverlay.groupCount

                        Item {
                            id: groupDelegate
                            required property int index
                            width: sliderArea.width / Math.max(mixerOverlay.groupCount, 1)
                            height: sliderArea.height

                            readonly property var grp: mixerOverlay.groupList[index] || ({})
                            readonly property bool isGen: grp.isGeneral || false
                            readonly property int grpVol: isGen ? mixerOverlay.generalVolume : (grp.volume || 0)
                            readonly property bool grpMuted: isGen ? mixerOverlay.generalMuted : (grp.muted || false)
                            readonly property int groupIdx: index

                            // Running apps for this group
                            readonly property var displayApps: {
                                void(mixerOverlay._audioTick)
                                if (!audioManager) return []
                                var apps = grp.apps || []
                                var running = []
                                for (var a = 0; a < apps.length; a++) {
                                    var streams = audioManager.findStreamsByApp(apps[a])
                                    if (streams.length > 0) running.push(apps[a])
                                }
                                // For General, also pick up any truly unassigned stragglers
                                if (isGen) {
                                    var unassigned = mixerOverlay.unassignedAppList
                                    for (var u = 0; u < unassigned.length; u++) {
                                        if (running.indexOf(unassigned[u]) < 0)
                                            running.push(unassigned[u])
                                    }
                                }
                                return running
                            }

                            // Column separator on right edge
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: parent.height * 0.7
                                color: themeManager.borderColor
                                opacity: 0.5
                                visible: index < mixerOverlay.groupCount - 1
                            }

                            // Highlight when dragging an app over this column
                            Rectangle {
                                anchors.fill: parent
                                color: themeManager.accentColor
                                opacity: mixerOverlay.dragTargetGroup === groupDelegate.groupIdx ? 0.10 : 0
                                radius: 8
                                z: -1

                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 4
                                spacing: 4

                                // Group name
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: grp.name || ""
                                    color: themeManager.textColor
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Mute button
                                Item {
                                    width: parent.width
                                    height: grpMuteBtn.height

                                    Rectangle {
                                        id: grpMuteBtn
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: grpMuteArea.containsMouse
                                               ? themeManager.overlayColor : "transparent"

                                        LucideIcon {
                                            anchors.centerIn: parent
                                            width: 16; height: 16
                                            source: grpMuted ? "qrc:/icons/lucide/volume-x.svg"
                                                             : "qrc:/icons/lucide/volume-2.svg"
                                            color: mixerOverlay.iconColor
                                        }

                                        MouseArea {
                                            id: grpMuteArea
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            hoverEnabled: true
                                            onClicked: {
                                                if (isGen) {
                                                    audioManager.setDefaultMuted(!grpMuted)
                                                } else {
                                                    audioMixerService.setGroupMuted(index, !grpMuted)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Vertical slider
                                Item {
                                    id: grpSliderArea
                                    width: parent.width
                                    height: parent.height
                                           - 16 - 4   // name
                                           - 28 - 4   // mute
                                           - grpPctText.height - 4 // percent
                                           - appBox.height         // app box
                                           - 8                     // top margin

                                    Rectangle {
                                        id: grpTrack
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: mixerOverlay.trackThick
                                        radius: width / 2
                                        color: themeManager.borderColor

                                        // Fill
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: parent.height * Math.min(grpVol / 100, 1)
                                            radius: parent.radius
                                            color: grpMuted ? themeManager.secondaryTextColor : mixerOverlay.barColor
                                        }

                                        // Knob
                                        Rectangle {
                                            width: mixerOverlay.thumbCross
                                            height: mixerOverlay.thumbAlong
                                            radius: mixerOverlay.thumbRadius
                                            color: mixerOverlay.knobColor
                                            border.width: 1
                                            border.color: themeManager.borderColor
                                            x: (parent.width - width) / 2
                                            y: Math.max(0, Math.min(parent.height - height,
                                                parent.height * (1 - Math.min(grpVol / 100, 1)) - height / 2))
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        onPressed: (mouse) => updateVol(mouse)
                                        onPositionChanged: (mouse) => { if (pressed) updateVol(mouse) }

                                        function updateVol(mouse) {
                                            var trackTop = grpTrack.y
                                            var trackH = grpTrack.height
                                            var pct = 1 - ((mouse.y - trackTop) / trackH)
                                            pct = Math.round(Math.max(0, Math.min(1, pct)) * 100)
                                            if (isGen) {
                                                audioManager.setDefaultVolume(pct)
                                            } else {
                                                audioMixerService.setGroupVolume(index, pct)
                                            }
                                        }
                                    }
                                }

                                // Percentage
                                Text {
                                    id: grpPctText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: grpVol + "%"
                                    color: grpMuted ? themeManager.secondaryTextColor : mixerOverlay.percentColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                // ─── App icon grid ───
                                Rectangle {
                                    id: appBox
                                    width: parent.width
                                    height: 80
                                    color: Qt.rgba(themeManager.textColor.r, themeManager.textColor.g, themeManager.textColor.b, 0.03)
                                    radius: 6

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        clip: true
                                        contentHeight: appGrid.height
                                        flickableDirection: Flickable.VerticalFlick

                                        Flow {
                                            id: appGrid
                                            width: parent.width
                                            spacing: 4

                                            Repeater {
                                                model: displayApps

                                                Item {
                                                    id: appTile
                                                    required property string modelData
                                                    width: mixerOverlay.appTileSize
                                                    height: mixerOverlay.appTileSize

                                                    property string appName: modelData

                                                    Drag.active: appDragHandler.active
                                                    Drag.keys: ["mixerApp"]
                                                    Drag.hotSpot.x: width / 2
                                                    Drag.hotSpot.y: height / 2

                                                    // Ghost that follows the cursor during drag
                                                    Rectangle {
                                                        id: appDragGhost
                                                        visible: appDragHandler.active
                                                        parent: panel
                                                        z: 500
                                                        width: mixerOverlay.appTileSize
                                                        height: mixerOverlay.appTileSize
                                                        radius: 6
                                                        color: Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.3)
                                                        border.width: 1
                                                        border.color: themeManager.accentColor
                                                        opacity: 0.9

                                                        Image {
                                                            anchors.centerIn: parent
                                                            width: 20; height: 20
                                                            source: "image://appicon/" + modelData
                                                            sourceSize: Qt.size(20, 20)
                                                            fillMode: Image.PreserveAspectFit
                                                        }
                                                    }

                                                    Rectangle {
                                                        id: appTileBg
                                                        anchors.fill: parent
                                                        radius: 6
                                                        color: appDragHandler.hovered
                                                               ? themeManager.overlayColor
                                                               : Qt.rgba(themeManager.textColor.r, themeManager.textColor.g, themeManager.textColor.b, 0.06)
                                                        border.width: appDragHandler.hovered ? 1 : 0
                                                        border.color: themeManager.borderColor
                                                        // Dim while dragging
                                                        opacity: appDragHandler.active ? 0.3 : 1.0

                                                        Image {
                                                            id: appIconImg
                                                            anchors.centerIn: parent
                                                            anchors.verticalCenterOffset: -5
                                                            width: 20; height: 20
                                                            source: "image://appicon/" + modelData
                                                            sourceSize: Qt.size(20, 20)
                                                            fillMode: Image.PreserveAspectFit
                                                            onStatusChanged: {
                                                                if (status === Image.Error) {
                                                                    visible = false
                                                                    appFallbackIcon.visible = true
                                                                }
                                                            }
                                                        }

                                                        LucideIcon {
                                                            id: appFallbackIcon
                                                            anchors.centerIn: parent
                                                            anchors.verticalCenterOffset: -5
                                                            width: 16; height: 16
                                                            source: "qrc:/icons/lucide/volume-2.svg"
                                                            color: themeManager.secondaryTextColor
                                                            visible: false
                                                        }

                                                        Text {
                                                            anchors.bottom: parent.bottom
                                                            anchors.bottomMargin: 2
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: parent.width - 4
                                                            text: modelData
                                                            color: themeManager.secondaryTextColor
                                                            font.pixelSize: 7
                                                            elide: Text.ElideRight
                                                            horizontalAlignment: Text.AlignHCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: appDragHandler
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        preventStealing: true
                                                        property bool active: false
                                                        property bool hovered: containsMouse && !active
                                                        property real startX: 0
                                                        property real startY: 0
                                                        property real panelMouseX: 0
                                                        property real panelMouseY: 0

                                                        onPressed: (mouse) => {
                                                            startX = mouse.x
                                                            startY = mouse.y
                                                        }

                                                        onPositionChanged: (mouse) => {
                                                            if (!pressed) return
                                                            var dx = mouse.x - startX
                                                            var dy = mouse.y - startY
                                                            if (!active && (dx*dx + dy*dy) > 64) {
                                                                active = true
                                                            }
                                                            if (active) {
                                                                // Map mouse to panel coords for ghost position
                                                                var mapped = mapToItem(panel, mouse.x, mouse.y)
                                                                appDragGhost.x = mapped.x - appDragGhost.width / 2
                                                                appDragGhost.y = mapped.y - appDragGhost.height / 2
                                                                panelMouseX = mapped.x
                                                                panelMouseY = mapped.y
                                                                // Update which group column is highlighted
                                                                mixerOverlay.updateDragTarget(mapped.x)
                                                            }
                                                        }

                                                        onReleased: {
                                                            if (active) {
                                                                // Drop on target group
                                                                var targetIdx = mixerOverlay.dragTargetGroup
                                                                if (targetIdx >= 0 && targetIdx !== groupDelegate.groupIdx) {
                                                                    audioMixerService.moveAppToGroup(modelData, targetIdx)
                                                                }
                                                                active = false
                                                                mixerOverlay.dragTargetGroup = -1
                                                            }
                                                        }

                                                        onClicked: {
                                                            if (!active) {
                                                                mixerOverlay.reassignAppName = modelData
                                                                mixerOverlay.reassignVisible = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── Separator before Mic ───
            Rectangle {
                visible: micColumn.visible
                width: 1
                height: parent.height * 0.85
                anchors.verticalCenter: parent.verticalCenter
                color: themeManager.borderColor
            }

            // ─── Mic column ───
            Item {
                id: micColumn
                visible: mixerOverlay.showMic
                width: visible ? 80 : 0
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.topMargin: 4
                    spacing: 4

                    // Label
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Mic"
                        color: themeManager.textColor
                        font.pixelSize: 12
                        font.bold: true
                    }

                    // Mute button
                    Item {
                        width: parent.width
                        height: micMuteBtn.height

                        Rectangle {
                            id: micMuteBtn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: micMuteArea.containsMouse
                                   ? themeManager.overlayColor : "transparent"

                            LucideIcon {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: audioMixerService.micMuted
                                        ? "qrc:/icons/lucide/mic-off.svg"
                                        : "qrc:/icons/lucide/mic.svg"
                                color: mixerOverlay.iconColor
                            }

                            MouseArea {
                                id: micMuteArea
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                onClicked: audioMixerService.setMicMuted(!audioMixerService.micMuted)
                            }
                        }
                    }

                    // Vertical slider
                    Item {
                        id: micSliderArea
                        width: parent.width
                        height: parent.height
                               - 16 - 4   // name
                               - 28 - 4   // mute
                               - micPctText.height - 4 // percent
                               - 8                     // top margin

                        Rectangle {
                            id: micTrack
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: mixerOverlay.trackThick
                            radius: width / 2
                            color: themeManager.borderColor

                            // Fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * Math.min(audioMixerService.micVolume / 100, 1)
                                radius: parent.radius
                                color: audioMixerService.micMuted ? themeManager.secondaryTextColor : mixerOverlay.barColor
                            }

                            // Knob
                            Rectangle {
                                width: mixerOverlay.thumbCross
                                height: mixerOverlay.thumbAlong
                                radius: mixerOverlay.thumbRadius
                                color: mixerOverlay.knobColor
                                border.width: 1
                                border.color: themeManager.borderColor
                                x: (parent.width - width) / 2
                                y: Math.max(0, Math.min(parent.height - height,
                                    parent.height * (1 - Math.min(audioMixerService.micVolume / 100, 1)) - height / 2))
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            onPressed: (mouse) => updateMicVol(mouse)
                            onPositionChanged: (mouse) => { if (pressed) updateMicVol(mouse) }

                            function updateMicVol(mouse) {
                                var trackTop = micTrack.y
                                var trackH = micTrack.height
                                var pct = 1 - ((mouse.y - trackTop) / trackH)
                                pct = Math.round(Math.max(0, Math.min(1, pct)) * 100)
                                audioMixerService.setMicVolume(pct)
                            }
                        }
                    }

                    // Percentage
                    Text {
                        id: micPctText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: audioMixerService.micVolume + "%"
                        color: audioMixerService.micMuted ? themeManager.secondaryTextColor : mixerOverlay.percentColor
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }
        }

        // ─── Reassign sub-overlay ───
        // Backdrop
        MouseArea {
            anchors.fill: parent
            visible: mixerOverlay.reassignVisible
            z: 90
            onClicked: mixerOverlay.reassignVisible = false
        }

        // Card
        Rectangle {
            visible: mixerOverlay.reassignVisible
            z: 100
            anchors.centerIn: parent
            width: 220
            height: reassignTitle.height + reassignList.height + 28
            radius: 12
            color: themeManager.backgroundColor
            border.width: 1
            border.color: themeManager.borderColor

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                    id: reassignTitle
                    text: "Move \"" + mixerOverlay.reassignAppName + "\""
                    color: themeManager.textColor
                    font.pixelSize: 13
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight
                }

                Column {
                    id: reassignList
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: audioMixerService ? audioMixerService.groupNames() : []

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: parent.width
                            height: 32
                            radius: 6
                            color: reassignItemMa.containsMouse ? themeManager.overlayColor : "transparent"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: themeManager.textColor
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: reassignItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    audioMixerService.moveAppToGroup(mixerOverlay.reassignAppName, index)
                                    mixerOverlay.reassignVisible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
