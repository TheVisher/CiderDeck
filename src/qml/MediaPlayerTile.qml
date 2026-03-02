import QtQuick
import Qt5Compat.GraphicalEffects

Card {
    id: mediaTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Art fade settings
    readonly property string artFadeMode: settings.artFadeMode || "bottom"
    readonly property real artPeakOpacity: settings.artPeakOpacity !== undefined ? settings.artPeakOpacity : 0.5
    readonly property real artFadePosition: settings.artFadePosition !== undefined ? settings.artFadePosition : 0.0

    // Info layout settings
    readonly property string infoLayout: settings.infoLayout || "left"
    readonly property int artSizeSetting: settings.artSize || 0
    readonly property real effectiveArtSize: artSizeSetting > 0 ? artSizeSetting
        : (sizeClass === "large" ? 80 : 56)

    // Progress bar sizing (VolumeTile slider pattern)
    readonly property real progressScale: settings.progressThickness || 1.0
    readonly property real progressTrackThick: 4 * progressScale
    readonly property real progressKnobScale: settings.progressKnobSize || 1.0
    readonly property string progressKnobShape: settings.progressKnobShape || "pill"
    readonly property real progressKnobBase: progressTrackThick + 12 * progressKnobScale
    readonly property real progressThumbCross: progressKnobShape === "square" ? progressKnobBase * 0.85 : progressKnobBase
    readonly property real progressThumbAlong: progressKnobShape === "circle" ? progressKnobBase
        : progressKnobShape === "square" ? progressKnobBase * 0.85
        : Math.max(progressKnobBase * 0.55, 8)
    readonly property real progressThumbRadius: progressKnobShape === "circle" ? progressKnobBase / 2
        : progressKnobShape === "square" ? 3
        : progressThumbAlong / 2

    // Time labels
    readonly property real timeLabelScale: settings.timeLabelScale || 1.0
    readonly property bool showTimeLabels: settings.showTimeLabels !== false

    // Transport button scaling
    readonly property real buttonScale: settings.buttonScale || 1.0
    readonly property real playPauseSize: 40 * buttonScale
    readonly property real skipSize: 28 * buttonScale
    readonly property real extraSize: 24 * buttonScale
    readonly property real transportSpacing: 20 * buttonScale

    // Player switcher
    readonly property bool showPlayerSwitcher: settings.showPlayerSwitcher !== false

    // Whether any player is available
    readonly property bool hasPlayer: mprisManager.currentPlayer !== ""

    // Seek drag state
    property bool seekDragging: false
    property real localProgress: 0

    Binding {
        target: mediaTile
        property: "localProgress"
        value: mprisManager.duration > 0 ? mprisManager.position / mprisManager.duration : 0
        when: !mediaTile.seekDragging
        restoreMode: Binding.RestoreNone
    }

    function openPlayer() {
        var desktop = mprisManager.desktopEntry
        if (desktop)
            appLaunchManager.launch(desktop, "", "", true)
    }

    // ── Empty state when no player running ──
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: !mediaTile.hasPlayer

        LucideIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(mediaTile.width, mediaTile.height) * 0.22
            height: width
            source: "qrc:/icons/lucide/music.svg"
            color: themeManager.secondaryTextColor
            opacity: 0.3
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No media playing"
            color: themeManager.secondaryTextColor
            font.pixelSize: 11 * mediaTile.contentScale
            opacity: 0.5
            visible: mediaTile.sizeClass !== "tiny"
        }
    }

    // ── Album art background with configurable fade via OpacityMask ──
    Item {
        id: bgArtContainer
        anchors.fill: parent
        visible: bgArt.status === Image.Ready && mediaTile.sizeClass !== "tiny" && mediaTile.hasPlayer
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Item {
                width: bgArtContainer.width
                height: bgArtContainer.height

                Rectangle {
                    anchors.fill: parent
                    visible: mediaTile.artFadeMode === "bottom"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: Math.max(0.01, mediaTile.artFadePosition); color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    visible: mediaTile.artFadeMode === "edges"
                    horizontalRadius: parent.width * 0.5
                    verticalRadius: parent.height * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: Math.max(0.01, mediaTile.artFadePosition); color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    visible: mediaTile.artFadeMode === "radial"
                    horizontalRadius: Math.min(parent.width, parent.height) * 0.5
                    verticalRadius: Math.min(parent.width, parent.height) * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: Math.max(0.01, mediaTile.artFadePosition); color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: mediaTile.artFadeMode === "none"
                    color: Qt.rgba(1, 1, 1, mediaTile.artPeakOpacity)
                }
            }
        }

        Image {
            id: bgArt
            anchors.fill: parent
            source: mprisManager.artUrl || ""
            fillMode: Image.PreserveAspectCrop
        }
    }

    // Placeholder gradient when no art available
    Rectangle {
        anchors.fill: parent
        visible: bgArt.status !== Image.Ready && mediaTile.sizeClass !== "tiny" && mediaTile.hasPlayer
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(themeManager.accentColor.r,
                                                          themeManager.accentColor.g,
                                                          themeManager.accentColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.3
            height: width
            source: mprisManager.playerIcon ? "image://appicon/" + mprisManager.playerIcon : ""
            fillMode: Image.PreserveAspectFit
            opacity: 0.15
            visible: source !== ""
        }
    }

    // ── Tiny: just play/pause button ──
    Item {
        anchors.fill: parent
        visible: mediaTile.sizeClass === "tiny" && mediaTile.hasPlayer

        LucideIcon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.4
            height: width
            source: mprisManager.playbackStatus === "Playing"
                    ? "qrc:/icons/lucide/pause.svg"
                    : "qrc:/icons/lucide/play.svg"
            color: themeManager.textColor

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                onClicked: mprisManager.playPause()
            }
        }
    }

    // ── Small: transport controls + optional player indicator ──
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: mediaTile.sizeClass === "small" && mediaTile.hasPlayer

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16 * mediaTile.buttonScale

            LucideIcon {
                width: mediaTile.skipSize; height: mediaTile.skipSize
                source: "qrc:/icons/lucide/skip-back.svg"
                color: themeManager.textColor
                opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.previous()
                }
            }
            LucideIcon {
                width: mediaTile.playPauseSize; height: mediaTile.playPauseSize
                source: mprisManager.playbackStatus === "Playing"
                        ? "qrc:/icons/lucide/pause.svg"
                        : "qrc:/icons/lucide/play.svg"
                color: themeManager.textColor
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.playPause()
                }
            }
            LucideIcon {
                width: mediaTile.skipSize; height: mediaTile.skipSize
                source: "qrc:/icons/lucide/skip-forward.svg"
                color: themeManager.textColor
                opacity: mprisManager.canGoNext ? 1.0 : 0.3
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.next()
                }
            }
        }

        // Player indicator (small)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: smallIndicatorRow.width
            height: smallIndicatorRow.height
            visible: mediaTile.showPlayerSwitcher

            Row {
                id: smallIndicatorRow
                spacing: 4

                Image {
                    source: mprisManager.playerIcon ? "image://appicon/" + mprisManager.playerIcon : ""
                    sourceSize.width: 12; sourceSize.height: 12
                    width: 12; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: source !== ""
                }
                Text {
                    text: mprisManager.currentPlayer
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 9 * mediaTile.contentScale
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }
                // Dots for multiple players
                Row {
                    spacing: 3
                    visible: mprisManager.playerCount > 1
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: mprisManager.playerNames
                        Rectangle {
                            required property string modelData
                            width: 3; height: 3; radius: 1.5
                            color: modelData === mprisManager.currentPlayer
                                   ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: mprisManager.selectNextPlayer()
            }
        }
    }

    // ── Medium/Large: info at top, progress + controls at bottom ──
    Item {
        anchors.fill: parent
        anchors.margins: 12
        visible: (mediaTile.sizeClass === "medium" || mediaTile.sizeClass === "large") && mediaTile.hasPlayer

        // ── Info section (art + text with layout-aware positioning) ──
        Item {
            id: infoSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: progressSection.top
            anchors.bottomMargin: progressSection.visible ? 8 : 0
            clip: true

            readonly property bool artVisible: mediaTile.infoLayout !== "text-only"
            readonly property bool textVisible: mediaTile.infoLayout !== "art-only"
            readonly property bool isStacked: mediaTile.infoLayout === "top"
                || mediaTile.infoLayout === "bottom" || mediaTile.infoLayout === "center"
            readonly property int textAlign: isStacked || mediaTile.infoLayout === "text-only"
                ? Text.AlignHCenter : Text.AlignLeft

            // Vertical centering for stacked layouts
            readonly property real stackedBlockH:
                (artVisible ? mediaTile.effectiveArtSize : 0)
                + (artVisible && textVisible ? 8 : 0)
                + (textVisible ? textCol.implicitHeight : 0)
            readonly property real stackedBlockY: Math.max(0, (height - stackedBlockH) / 2)

            Item {
                id: artBox
                visible: infoSection.artVisible
                width: mediaTile.effectiveArtSize
                height: mediaTile.effectiveArtSize

                x: {
                    switch (mediaTile.infoLayout) {
                        case "right": return infoSection.width - width
                        case "top":
                        case "bottom":
                        case "center":
                        case "art-only":
                            return (infoSection.width - width) / 2
                        default: return 0  // left
                    }
                }
                y: {
                    switch (mediaTile.infoLayout) {
                        case "left":
                        case "right":
                            return Math.max(0, (infoSection.height - height) / 2)
                        case "bottom":
                            return infoSection.stackedBlockY
                                + (infoSection.textVisible ? textCol.implicitHeight + 8 : 0)
                        default: // top, center, art-only
                            return infoSection.stackedBlockY
                    }
                }

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: mprisManager.artUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(themeManager.accentColor.r,
                                   themeManager.accentColor.g,
                                   themeManager.accentColor.b, 0.2)
                    visible: albumArt.status !== Image.Ready

                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.6
                        height: width
                        source: mprisManager.playerIcon ? "image://appicon/" + mprisManager.playerIcon : ""
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.7
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: themeManager.borderColor
                }
            }

            Column {
                id: textCol
                visible: infoSection.textVisible
                spacing: 2

                width: {
                    if (infoSection.isStacked || mediaTile.infoLayout === "text-only")
                        return infoSection.width
                    return infoSection.width - (infoSection.artVisible ? mediaTile.effectiveArtSize + 12 : 0)
                }
                x: {
                    switch (mediaTile.infoLayout) {
                        case "left":
                            return infoSection.artVisible ? mediaTile.effectiveArtSize + 12 : 0
                        case "right":
                            return 0
                        default: return 0  // stacked, text-only: full width
                    }
                }
                y: {
                    switch (mediaTile.infoLayout) {
                        case "left":
                        case "right":
                            return Math.max(0, (infoSection.height - implicitHeight) / 2)
                        case "top":
                        case "center":
                            return infoSection.stackedBlockY
                                + (infoSection.artVisible ? mediaTile.effectiveArtSize + 8 : 0)
                        default: // bottom, text-only
                            return infoSection.stackedBlockY
                    }
                }

                MarqueeText {
                    text: mprisManager.title || "No track"
                    color: themeManager.textColor
                    font.pixelSize: 15 * mediaTile.contentScale
                    font.weight: Font.DemiBold
                    width: parent.width
                    height: implicitHeight
                    horizontalAlignment: infoSection.textAlign
                }
                MarqueeText {
                    text: mprisManager.artist || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 13 * mediaTile.contentScale
                    width: parent.width
                    height: text !== "" ? implicitHeight : 0
                    visible: text !== ""
                    horizontalAlignment: infoSection.textAlign
                }
                MarqueeText {
                    text: mprisManager.album || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 11 * mediaTile.contentScale
                    width: parent.width
                    height: (text !== "" && mediaTile.sizeClass === "large") ? implicitHeight : 0
                    visible: text !== "" && mediaTile.sizeClass === "large"
                    horizontalAlignment: infoSection.textAlign
                }
            }

            // Swipe to switch players + tap art to open player app
            MouseArea {
                id: infoSwipeArea
                anchors.fill: parent

                property real startX: 0
                property real startY: 0
                property bool isSwiping: false

                onPressed: (mouse) => {
                    startX = mouse.x
                    startY = mouse.y
                    isSwiping = false
                }
                onPositionChanged: (mouse) => {
                    var dx = Math.abs(mouse.x - startX)
                    var dy = Math.abs(mouse.y - startY)
                    if (dx > 30 && dx > dy) isSwiping = true
                }
                onReleased: (mouse) => {
                    if (isSwiping) {
                        var dx = mouse.x - startX
                        if (dx > 50) mprisManager.selectPreviousPlayer()
                        else if (dx < -50) mprisManager.selectNextPlayer()
                    } else {
                        // Tap on album art → open the player app
                        var artPos = artBox.mapFromItem(infoSwipeArea, mouse.x, mouse.y)
                        if (artBox.visible &&
                            artPos.x >= 0 && artPos.x <= artBox.width &&
                            artPos.y >= 0 && artPos.y <= artBox.height) {
                            mediaTile.openPlayer()
                        }
                    }
                }
            }
        }

        // ── Progress section (time labels + track + knob) ──
        Item {
            id: progressSection
            anchors.bottom: transportRow.top
            anchors.bottomMargin: visible ? 8 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: mprisManager.duration > 0
                ? (mediaTile.showTimeLabels ? timeLabelsRow.height + 4 : 0)
                  + Math.max(mediaTile.progressTrackThick, mediaTile.progressThumbCross)
                : 0
            visible: mprisManager.duration > 0

            Item {
                id: timeLabelsRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: mediaTile.showTimeLabels ? posLabel.implicitHeight : 0
                visible: mediaTile.showTimeLabels

                Text {
                    id: posLabel
                    anchors.left: parent.left
                    text: formatTime(mediaTile.seekDragging
                          ? mediaTile.localProgress * mprisManager.duration
                          : mprisManager.position)
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * mediaTile.timeLabelScale * mediaTile.contentScale
                }

                Text {
                    id: durLabel
                    anchors.right: parent.right
                    text: formatTime(mprisManager.duration)
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * mediaTile.timeLabelScale * mediaTile.contentScale
                }
            }

            Rectangle {
                id: progressTrack
                anchors.left: parent.left
                anchors.right: parent.right
                y: (mediaTile.showTimeLabels ? timeLabelsRow.height + 4 : 0)
                   + (Math.max(mediaTile.progressTrackThick, mediaTile.progressThumbCross)
                      - mediaTile.progressTrackThick) / 2
                height: mediaTile.progressTrackThick
                radius: height / 2
                color: themeManager.borderColor

                Rectangle {
                    width: parent.width * mediaTile.localProgress
                    height: parent.height
                    radius: parent.radius
                    color: themeManager.accentColor
                }

                Rectangle {
                    width: mediaTile.progressThumbAlong
                    height: mediaTile.progressThumbCross
                    radius: mediaTile.progressThumbRadius
                    color: "white"
                    border.width: 1
                    border.color: themeManager.borderColor
                    x: Math.max(0, Math.min(progressTrack.width - width,
                        progressTrack.width * mediaTile.localProgress - width / 2))
                    y: (progressTrack.height - height) / 2
                }
            }

            MouseArea {
                x: progressTrack.x - 8
                y: progressTrack.y - 8
                width: progressTrack.width + 16
                height: progressTrack.height + 16
                preventStealing: true

                onPressed: (mouse) => {
                    if (mprisManager.duration > 0 && mprisManager.canSeek) {
                        mediaTile.seekDragging = true
                        updateSeek(mouse)
                    }
                }
                onPositionChanged: (mouse) => {
                    if (mediaTile.seekDragging) updateSeek(mouse)
                }
                onReleased: {
                    if (mediaTile.seekDragging) {
                        mprisManager.setPosition(mediaTile.localProgress * mprisManager.duration)
                        mediaTile.seekDragging = false
                    }
                }
                onCanceled: {
                    mediaTile.seekDragging = false
                }

                function updateSeek(mouse) {
                    var progress = (mouse.x - 8) / progressTrack.width
                    mediaTile.localProgress = Math.max(0, Math.min(1, progress))
                }
            }
        }

        // ── Transport controls ──
        Row {
            id: transportRow
            anchors.bottom: playerIndicator.top
            anchors.bottomMargin: playerIndicator.visible ? 4 : 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: mediaTile.transportSpacing

            // Left extra: shuffle (Spotify) or rewind/seek-back (browser)
            Item {
                width: mediaTile.extraSize; height: mediaTile.extraSize
                anchors.verticalCenter: parent.verticalCenter
                visible: mprisManager.isSpotify || mprisManager.canSeek

                LucideIcon {
                    anchors.fill: parent
                    source: mprisManager.isSpotify
                            ? "qrc:/icons/lucide/shuffle.svg"
                            : "qrc:/icons/lucide/rewind.svg"
                    color: mprisManager.isSpotify && mprisManager.shuffle
                           ? themeManager.accentColor
                           : themeManager.textColor
                    opacity: mprisManager.isSpotify
                             ? (mprisManager.shuffle ? 1.0 : 0.4)
                             : 0.7
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 3 * mediaTile.buttonScale
                    width: 4 * mediaTile.buttonScale; height: 4 * mediaTile.buttonScale
                    radius: width / 2
                    color: themeManager.accentColor
                    visible: mprisManager.isSpotify && mprisManager.shuffle
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        if (mprisManager.isSpotify)
                            mprisManager.toggleShuffle()
                        else
                            mprisManager.skipBackward(10)
                    }
                }
            }

            LucideIcon {
                width: mediaTile.skipSize; height: mediaTile.skipSize
                source: "qrc:/icons/lucide/skip-back.svg"
                color: themeManager.textColor
                opacity: mprisManager.canGoPrevious ? 1.0 : 0.3
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.previous()
                }
            }

            LucideIcon {
                width: mediaTile.playPauseSize; height: mediaTile.playPauseSize
                source: mprisManager.playbackStatus === "Playing"
                        ? "qrc:/icons/lucide/pause.svg"
                        : "qrc:/icons/lucide/play.svg"
                color: themeManager.textColor
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.playPause()
                }
            }

            LucideIcon {
                width: mediaTile.skipSize; height: mediaTile.skipSize
                source: "qrc:/icons/lucide/skip-forward.svg"
                color: themeManager.textColor
                opacity: mprisManager.canGoNext ? 1.0 : 0.3
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: mprisManager.next()
                }
            }

            // Right extra: repeat (Spotify) or fast-forward/seek-fwd (browser)
            Item {
                width: mediaTile.extraSize; height: mediaTile.extraSize
                anchors.verticalCenter: parent.verticalCenter
                visible: mprisManager.isSpotify || mprisManager.canSeek

                LucideIcon {
                    anchors.fill: parent
                    source: mprisManager.isSpotify
                            ? (mprisManager.loopStatus === "Track"
                               ? "qrc:/icons/lucide/repeat-1.svg"
                               : "qrc:/icons/lucide/repeat.svg")
                            : "qrc:/icons/lucide/fast-forward.svg"
                    color: mprisManager.isSpotify && mprisManager.loopStatus !== "None"
                           ? themeManager.accentColor
                           : themeManager.textColor
                    opacity: mprisManager.isSpotify
                             ? (mprisManager.loopStatus !== "None" ? 1.0 : 0.4)
                             : 0.7
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 3 * mediaTile.buttonScale
                    width: 4 * mediaTile.buttonScale; height: 4 * mediaTile.buttonScale
                    radius: width / 2
                    color: themeManager.accentColor
                    visible: mprisManager.isSpotify && mprisManager.loopStatus !== "None"
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        if (mprisManager.isSpotify)
                            mprisManager.cycleLoopStatus()
                        else
                            mprisManager.skipForward(10)
                    }
                }
            }
        }

        // ── Player indicator (bottom, tappable to cycle) ──
        Item {
            id: playerIndicator
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: mediaTile.showPlayerSwitcher ? indicatorRow.height : 0
            visible: mediaTile.showPlayerSwitcher

            Row {
                id: indicatorRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Image {
                    source: mprisManager.playerIcon ? "image://appicon/" + mprisManager.playerIcon : ""
                    sourceSize.width: 14; sourceSize.height: 14
                    width: 14; height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: source !== ""
                }

                Text {
                    text: mprisManager.currentPlayer
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * mediaTile.contentScale
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Player dots when multiple active
                Row {
                    spacing: 3
                    visible: mprisManager.playerCount > 1
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: mprisManager.playerNames
                        Rectangle {
                            required property string modelData
                            width: 4; height: 4; radius: 2
                            color: modelData === mprisManager.currentPlayer
                                   ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: indicatorRow
                anchors.margins: -6
                onClicked: mprisManager.selectNextPlayer()
            }
        }
    }

    function formatTime(microseconds) {
        var totalSecs = Math.floor(microseconds / 1000000)
        var mins = Math.floor(totalSecs / 60)
        var secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}
