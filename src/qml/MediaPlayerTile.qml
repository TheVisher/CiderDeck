import QtQuick
import Qt5Compat.GraphicalEffects

Card {
    id: mediaTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property string preferredPlayer: settings.preferredPlayer || ""
    readonly property real controlContentScale: Math.max(0.5, Math.min(
        contentScale,
        (width - 24) / (((sizeClass === "tiny" || sizeClass === "small") ? 120 : 224)
                        * buttonScale)))

    // Art fade settings
    readonly property string artFadeMode: settings.artFadeMode || "bottom"
    readonly property real artPeakOpacity: settings.artPeakOpacity !== undefined ? settings.artPeakOpacity : 0.5
    readonly property real artFadePosition: settings.artFadePosition !== undefined ? settings.artFadePosition : 0.0
    readonly property bool showBackgroundArt: settings.showBackgroundArt !== false
    readonly property real backgroundArtZoom: Math.max(1.0, Math.min(
        3.0, settings.backgroundArtZoom || 1.0))

    // Info layout settings
    readonly property string infoLayout: settings.infoLayout || "left"
    readonly property bool showCoverThumbnail: settings.showCoverThumbnail !== false
    readonly property string textHorizontalPosition: settings.textHorizontalPosition
        || ((infoLayout === "top" || infoLayout === "bottom" || infoLayout === "center"
             || infoLayout === "text-only") ? "center" : "left")
    readonly property string textVerticalPosition: settings.textVerticalPosition || "center"
    readonly property int artSizeSetting: settings.artSize || 0
    readonly property real effectiveArtSize: Math.min(
        (artSizeSetting > 0 ? artSizeSetting : (sizeClass === "large" ? 80 : 56)) * contentScale,
        width * 0.45,
        height * 0.55)

    readonly property real artworkElementScale:
        (sizeClass === "medium" || sizeClass === "large")
        ? contentLayout.elementScale("artwork") : 1.0
    readonly property real progressElementScale:
        (sizeClass === "medium" || sizeClass === "large")
        ? contentLayout.elementScale("progress") : 1.0
    readonly property real controlsElementScale:
        (sizeClass === "medium" || sizeClass === "large")
        ? contentLayout.elementScale("controls") : 1.0
    readonly property real playerElementScale:
        (sizeClass === "medium" || sizeClass === "large")
        ? contentLayout.elementScale("player") : 1.0

    // Progress bar sizing (VolumeTile slider pattern)
    readonly property real progressScale: settings.progressThickness || 1.0
    readonly property real progressTrackThick: 4 * progressScale * progressElementScale
    readonly property real progressKnobScale: settings.progressKnobSize || 1.0
    readonly property string progressKnobShape: settings.progressKnobShape || "pill"
    readonly property real progressKnobBase: progressTrackThick
        + 12 * progressKnobScale * progressElementScale
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
    readonly property real playPauseSize: 40 * buttonScale * controlContentScale
                                                * controlsElementScale
    readonly property real skipSize: 28 * buttonScale * controlContentScale
                                           * controlsElementScale
    readonly property real extraSize: 24 * buttonScale * controlContentScale
                                            * controlsElementScale
    readonly property real transportSpacing: 20 * buttonScale * controlContentScale
                                                    * controlsElementScale
    readonly property string controlsAlignment: settings.controlsAlignment || "center"

    // Player switcher
    readonly property bool showPlayerSwitcher: settings.showPlayerSwitcher !== false

    // Whether any player is available
    readonly property bool hasPlayer: mprisManager.currentPlayer !== ""

    // Seek drag state
    property bool seekDragging: false
    property real localProgress: 0

    function applyPreferredPlayer() {
        mprisManager.selectPreferredPlayer(preferredPlayer)
    }

    Component.onCompleted: applyPreferredPlayer()
    onPreferredPlayerChanged: applyPreferredPlayer()

    Connections {
        target: mprisManager
        function onPlayersChanged() { mediaTile.applyPreferredPlayer() }
    }

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
        visible: !mediaTile.hasPlayer && !mediaTile.contentEditMode

        LucideIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(mediaTile.width, mediaTile.height) * 0.22 * mediaTile.contentScale
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
        visible: mediaTile.showBackgroundArt && bgArt.status === Image.Ready
                 && mediaTile.sizeClass !== "tiny" && mediaTile.hasPlayer
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
            scale: mediaTile.backgroundArtZoom
            smooth: true
            mipmap: true
        }
    }

    // Placeholder gradient when no art available
    Rectangle {
        anchors.fill: parent
        visible: bgArt.status !== Image.Ready && mediaTile.sizeClass !== "tiny" && mediaTile.hasPlayer
        opacity: mediaTile.surfaceOpacity
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
                enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                enabled: !mediaTile.contentEditMode
                onClicked: mprisManager.selectNextPlayer()
            }
        }
    }

    // ── Medium/Large: info at top, progress + controls at bottom ──
    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 12
        visible: (mediaTile.sizeClass === "medium" || mediaTile.sizeClass === "large")
                 && (mediaTile.hasPlayer || mediaTile.contentEditMode)

        // ── Info section (art + text with layout-aware positioning) ──
        Item {
            id: infoSection
            anchors.fill: parent
            clip: false

            readonly property bool artVisible: mediaTile.showCoverThumbnail
                && mediaTile.infoLayout !== "text-only"
                && contentLayout.elementVisible("artwork")
            readonly property bool textVisible: mediaTile.infoLayout !== "art-only"
                && contentLayout.elementVisible("trackInfo")
            readonly property bool isStacked: mediaTile.infoLayout === "top"
                || mediaTile.infoLayout === "bottom" || mediaTile.infoLayout === "center"
            readonly property int textAlign: mediaTile.textHorizontalPosition === "right"
                ? Text.AlignRight
                : (mediaTile.textHorizontalPosition === "center" ? Text.AlignHCenter : Text.AlignLeft)
            readonly property real usableHeight: {
                if (progressSection.visible) return Math.max(0, progressSection.y - 8)
                if (transportItem.visible) return Math.max(0, transportItem.y - 8)
                if (playerIndicator.visible) return Math.max(0, playerIndicator.y - 8)
                return height
            }

            // Vertical centering for stacked layouts
            readonly property real stackedBlockH:
                (artVisible ? artBox.height : 0)
                + (artVisible && textVisible ? 8 : 0)
                + (textVisible ? textCol.implicitHeight : 0)
            readonly property real stackedBlockY: Math.max(0, (usableHeight - stackedBlockH) / 2)
            readonly property real textAreaTop: artVisible
                && (mediaTile.infoLayout === "top" || mediaTile.infoLayout === "center")
                ? artBox.y + artBox.height + 8 : 0
            readonly property real textAreaBottom: artVisible && mediaTile.infoLayout === "bottom"
                ? artBox.y - 8 : usableHeight

            Item {
                id: artBox
                visible: infoSection.artVisible
                width: mediaTile.effectiveArtSize * mediaTile.artworkElementScale
                height: width
                z: mediaTile.selectedElement === "artwork" ? 20 : 1

                x: {
                    if (contentLayout.hasSavedValue("artwork", "x"))
                        return contentLayout.elementX("artwork")
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
                    if (contentLayout.hasSavedValue("artwork", "y"))
                        return contentLayout.elementY("artwork")
                    switch (mediaTile.infoLayout) {
                        case "left":
                        case "right":
                            return Math.max(0, (infoSection.usableHeight - height) / 2)
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

                ContentEditableFrame { host: contentLayout; elementId: "artwork" }
            }

            Item {
                id: trackInfoItem
                visible: infoSection.textVisible
                height: textCol.implicitHeight
                z: mediaTile.selectedElement === "trackInfo" ? 20 : 1

                width: {
                    if (infoSection.isStacked || mediaTile.infoLayout === "text-only")
                        return infoSection.width
                    return infoSection.width - (infoSection.artVisible ? artBox.width + 12 : 0)
                }
                x: {
                    if (contentLayout.hasSavedValue("trackInfo", "x"))
                        return contentLayout.elementX("trackInfo")
                    switch (mediaTile.infoLayout) {
                        case "left":
                            return infoSection.artVisible ? artBox.width + 12 : 0
                        case "right":
                            return 0
                        default: return 0  // stacked, text-only: full width
                    }
                }
                y: {
                    if (contentLayout.hasSavedValue("trackInfo", "y"))
                        return contentLayout.elementY("trackInfo")
                    var availableTop = infoSection.textAreaTop
                    var availableHeight = Math.max(0, infoSection.textAreaBottom - availableTop)
                    if (mediaTile.textVerticalPosition === "top")
                        return availableTop
                    if (mediaTile.textVerticalPosition === "bottom")
                        return Math.max(availableTop, infoSection.textAreaBottom - implicitHeight)
                    if (mediaTile.textVerticalPosition === "center")
                        return availableTop + Math.max(0, (availableHeight - implicitHeight) / 2)

                    switch (mediaTile.infoLayout) {
                        case "left":
                        case "right":
                            return Math.max(0, (infoSection.height - implicitHeight) / 2)
                        case "top":
                        case "center":
                            return infoSection.stackedBlockY
                                + (infoSection.artVisible ? artBox.height + 8 : 0)
                        default: // bottom, text-only
                            return infoSection.stackedBlockY
                    }
                }

                Column {
                    id: textCol
                    anchors.fill: parent
                    spacing: 2 * contentLayout.elementScale("trackInfo")

                    MarqueeText {
                        text: mprisManager.title || "No track"
                        color: themeManager.textColor
                        font.pixelSize: 15 * mediaTile.contentScale
                                        * contentLayout.elementFontScale("trackInfo")
                        font.weight: Font.DemiBold
                        width: parent.width
                        height: implicitHeight
                        horizontalAlignment: infoSection.textAlign
                    }
                    MarqueeText {
                        text: mprisManager.artist || (mediaTile.contentEditMode ? "Artist" : "")
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 13 * mediaTile.contentScale
                                        * contentLayout.elementFontScale("trackInfo")
                        width: parent.width
                        height: text !== "" ? implicitHeight : 0
                        visible: text !== ""
                        horizontalAlignment: infoSection.textAlign
                    }
                    MarqueeText {
                        text: mprisManager.album || (mediaTile.contentEditMode ? "Album" : "")
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 11 * mediaTile.contentScale
                                        * contentLayout.elementFontScale("trackInfo")
                        width: parent.width
                        height: (text !== "" && mediaTile.sizeClass === "large") ? implicitHeight : 0
                        visible: text !== "" && mediaTile.sizeClass === "large"
                        horizontalAlignment: infoSection.textAlign
                    }
                }

                ContentEditableFrame { host: contentLayout; elementId: "trackInfo" }
            }

            // Swipe to switch players + tap art to open player app
            MouseArea {
                id: infoSwipeArea
                anchors.fill: parent
                enabled: !mediaTile.contentEditMode

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
            width: parent.width
            x: contentLayout.hasSavedValue("progress", "x")
               ? contentLayout.elementX("progress") : 0
            y: {
                if (contentLayout.hasSavedValue("progress", "y"))
                    return contentLayout.elementY("progress")
                var nextY = parent.height
                if (transportItem.visible) nextY = transportItem.y - 8
                else if (playerIndicator.visible) nextY = playerIndicator.y - 8
                return Math.max(0, nextY - height)
            }
            height: mprisManager.duration > 0
                ? (mediaTile.showTimeLabels ? timeLabelsRow.height + 4 : 0)
                  + Math.max(mediaTile.progressTrackThick, mediaTile.progressThumbCross)
                : (mediaTile.contentEditMode
                   ? (mediaTile.showTimeLabels ? timeLabelsRow.height + 4 : 0)
                     + Math.max(mediaTile.progressTrackThick, mediaTile.progressThumbCross)
                   : 0)
            visible: (mprisManager.duration > 0 || mediaTile.contentEditMode)
                     && contentLayout.elementVisible("progress")
            z: mediaTile.selectedElement === "progress" ? 20 : 1

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
                                    * contentLayout.elementFontScale("progress")
                    renderType: Text.NativeRendering
                }

                Text {
                    id: durLabel
                    anchors.right: parent.right
                    text: formatTime(mprisManager.duration)
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * mediaTile.timeLabelScale * mediaTile.contentScale
                                    * contentLayout.elementFontScale("progress")
                    renderType: Text.NativeRendering
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
                enabled: !mediaTile.contentEditMode

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

            ContentEditableFrame { host: contentLayout; elementId: "progress" }
        }

        // ── Transport controls ──
        Item {
            id: transportItem
            width: transportRow.implicitWidth
            height: transportRow.implicitHeight
            visible: contentLayout.elementVisible("controls")
            x: contentLayout.hasSavedValue("controls", "x")
               ? contentLayout.elementX("controls")
               : mediaTile.controlsAlignment === "left" ? 0
               : mediaTile.controlsAlignment === "right" ? parent.width - width
               : (parent.width - width) / 2
            y: contentLayout.hasSavedValue("controls", "y")
               ? contentLayout.elementY("controls")
               : (playerIndicator.visible ? playerIndicator.y - 4 : parent.height) - height
            z: mediaTile.selectedElement === "controls" ? 20 : 1

            Row {
                id: transportRow
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
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
                    enabled: !mediaTile.contentEditMode
                    onClicked: {
                        if (mprisManager.isSpotify)
                            mprisManager.cycleLoopStatus()
                        else
                            mprisManager.skipForward(10)
                    }
                }
                }
            }

            ContentEditableFrame { host: contentLayout; elementId: "controls" }
        }

        // ── Player indicator (bottom, tappable to cycle) ──
        Item {
            id: playerIndicator
            width: indicatorRow.width
            height: mediaTile.showPlayerSwitcher ? indicatorRow.height : 0
            x: contentLayout.hasSavedValue("player", "x")
               ? contentLayout.elementX("player") : (parent.width - width) / 2
            y: contentLayout.hasSavedValue("player", "y")
               ? contentLayout.elementY("player") : parent.height - height
            visible: mediaTile.showPlayerSwitcher && contentLayout.elementVisible("player")
            z: mediaTile.selectedElement === "player" ? 20 : 1

            Row {
                id: indicatorRow
                anchors.centerIn: parent
                spacing: 5 * mediaTile.playerElementScale

                Image {
                    source: mprisManager.playerIcon ? "image://appicon/" + mprisManager.playerIcon : ""
                    sourceSize.width: width; sourceSize.height: height
                    width: 14 * mediaTile.playerElementScale
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    visible: source !== ""
                }

                Text {
                    text: mprisManager.currentPlayer
                          || (mediaTile.contentEditMode ? "Player" : "")
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * mediaTile.contentScale
                                    * contentLayout.elementFontScale("player")
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }

                // Player dots when multiple active
                Row {
                    spacing: 3 * mediaTile.playerElementScale
                    visible: mprisManager.playerCount > 1
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: mprisManager.playerNames
                        Rectangle {
                            required property string modelData
                            width: 4 * mediaTile.playerElementScale
                            height: width; radius: width / 2
                            color: modelData === mprisManager.currentPlayer
                                   ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: indicatorRow
                anchors.margins: -6
                enabled: !mediaTile.contentEditMode
                onClicked: mprisManager.selectNextPlayer()
            }

            ContentEditableFrame { host: contentLayout; elementId: "player" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: mediaTile; canvas: contentCanvas; tileId: mediaTile.tileId
        settings: mediaTile.settings; contentEditMode: mediaTile.contentEditMode
        selectedElement: mediaTile.selectedElement; contentScale: mediaTile.contentScale
        elements: [
            { id: "artwork", label: "Artwork", scale: 1, textScale: 1,
              visible: true, hasText: false },
            { id: "trackInfo", label: "Track info", scale: 1, textScale: 1,
              visible: true, hasText: true, itemGrowth: "vertical",
              textGrowth: "vertical" },
            { id: "progress", label: "Progress", scale: 1, textScale: 1,
              visible: true, hasText: true, itemGrowth: "vertical",
              textGrowth: "vertical" },
            { id: "controls", label: "Playback controls", scale: 1, textScale: 1,
              visible: true, hasText: false },
            { id: "player", label: "Player indicator", scale: 1, textScale: 1,
              visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "artwork") return artBox
            if (elementId === "trackInfo") return trackInfoItem
            if (elementId === "progress") return progressSection
            if (elementId === "controls") return transportItem
            if (elementId === "player") return playerIndicator
            return null
        }
    }

    function formatTime(microseconds) {
        var totalSecs = Math.floor(microseconds / 1000000)
        var mins = Math.floor(totalSecs / 60)
        var secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}
