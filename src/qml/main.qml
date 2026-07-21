import QtQuick
import QtQuick.Window

Window {
    id: root

    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    title: "CiderDeck"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.025, 0.035, 0.05, 0.68)
        z: -2
    }

    // Grid math helpers — use actual window size (set by layer-shell or C++)
    readonly property int gridColumns: deckConfig.gridColumns
    readonly property int gridRows: deckConfig.gridRows
    readonly property int gridGap: deckConfig.gridGap
    readonly property int gridPadding: deckConfig.padding
    readonly property real cellWidth: (width - gridPadding * 2 - gridGap * (gridColumns - 1)) / gridColumns
    readonly property real cellHeight: (height - gridPadding * 2 - gridGap * (gridRows - 1)) / gridRows

    // Transient state for editing the contents inside a tile. Persisted item
    // positions and scales live in that tile's settings map.
    property string contentEditTileId: ""
    property string contentEditElement: ""
    property var contentScaleValidator: null
    property var contentItemValueValidator: null
    property string contentValidatorOwner: ""
    property string contentEditConstraint: ""

    function beginContentEdit(tileId, initialElement) {
        editController.exitEditMode()
        contentEditTileId = tileId
        contentEditElement = initialElement || "temperature"
        contentEditConstraint = ""
        // Weather lives on the right side in the default deck. Put its controls
        // on the opposite side while editing so the tile remains visible.
        if (settingsPanel.isOpen)
            settingsPanel.moveForContentEdit(true)
    }

    function endContentEdit() {
        contentEditTileId = ""
        contentEditElement = ""
        contentScaleValidator = null
        contentItemValueValidator = null
        contentValidatorOwner = ""
        contentEditConstraint = ""
        if (settingsPanel.isOpen)
            settingsPanel.moveForContentEdit(false)
    }

    function clearContentValidators(owner) {
        if (owner && contentValidatorOwner !== owner) return
        contentScaleValidator = null
        contentItemValueValidator = null
        contentValidatorOwner = ""
    }

    function syncKeyboardInteractivity() {
        deckApp.setKeyboardEnabled(editController.editing
                                   || settingsPanel.isOpen
                                   || updateService.terminalActive)
    }

    // Background touch area for context menu and edit mode exit
    MouseArea {
        id: backgroundArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.targetTileId = ""
                contextMenu.popup(mouse.x, mouse.y)
            } else if (editController.editing) {
                editController.exitEditMode()
            }
        }

        onPressAndHold: {
            editController.enterEditMode()
        }

    }

    // A window-level shortcut works regardless of which tile or settings control
    // currently owns QML focus.
    Shortcut {
        sequence: "Esc"
        enabled: root.contentEditTileId !== "" || settingsPanel.isOpen || editController.editing
        context: Qt.WindowShortcut
        onActivated: {
            if (root.contentEditTileId !== "")
                root.endContentEdit()
            else if (settingsPanel.isOpen)
                settingsPanel.close()
            else
                editController.exitEditMode()
        }
    }

    // Edit mode border indicator — gradient edges that fade toward center
    Item {
        anchors.fill: parent
        z: 150
        visible: editController.editing

        // Top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: themeManager.accentColor }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: themeManager.accentColor }
            }
        }
        // Bottom edge
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: themeManager.accentColor }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: themeManager.accentColor }
            }
        }
        // Left edge
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 3
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: themeManager.accentColor }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: themeManager.accentColor }
            }
        }
        // Right edge
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 3
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: themeManager.accentColor }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: themeManager.accentColor }
            }
        }

        // Center guide lines
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: themeManager.accentColor
            opacity: 0.2
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: themeManager.accentColor
            opacity: 0.2
        }

        // "Done" badge top-center (tappable to exit edit mode)
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 4
            width: editLabel.width + 24
            height: 28
            radius: 14
            color: doneBtnArea.containsMouse
                   ? Qt.lighter(themeManager.accentColor, 1.2)
                   : themeManager.accentColor

            Text {
                id: editLabel
                anchors.centerIn: parent
                text: "Done  (ESC)"
                color: "white"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: doneBtnArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: editController.exitEditMode()
            }
        }
    }

    // Interactive horizontal page track
    PagePager {
        id: pagePager
        anchors.fill: parent

        gridColumns: root.gridColumns
        gridRows: root.gridRows
        gridGap: root.gridGap
        gridPadding: root.gridPadding
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
    }

    // Drag ghost overlay
    Rectangle {
        id: dragGhost
        visible: editController.dragTileId !== ""
        x: root.gridPadding + editController.ghostCol * (root.cellWidth + root.gridGap)
        y: root.gridPadding + editController.ghostRow * (root.cellHeight + root.gridGap)
        width: root.cellWidth * editController.ghostColSpan + root.gridGap * (editController.ghostColSpan - 1)
        height: root.cellHeight * editController.ghostRowSpan + root.gridGap * (editController.ghostRowSpan - 1)
        radius: deckConfig.cardRadius
        color: editController.ghostValid ? "#404488ff" : "#40e53935"
        border.width: 2
        border.color: editController.ghostValid ? themeManager.accentColor : themeManager.errorColor
        z: 100
    }

    // Page navigation strip (dots + swipe + arrows)
    PageDots {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        pageCount: deckConfig.pageCount
        currentPage: deckConfig.currentPage
        onPageRequested: (index) => pagePager.goToPage(index)
        onSwipeStarted: pagePager.beginSwipe()
        onSwipeUpdated: (deltaX) => pagePager.updateSwipe(deltaX)
        onSwipeFinished: (deltaX, velocityX) => pagePager.endSwipe(deltaX, velocityX)
        z: 50
    }

    // Toast stack
    ToastStack {
        z: 200
    }

    // Mixer overlay (between toasts and settings panel)
    MixerOverlay {
        id: mixerOverlay
        z: 250
    }

    // Enable keyboard only when edit mode or settings panel is open
    // (so ESC works), disable otherwise (touch never steals focus)
    Connections {
        target: editController
        function onEditingChanged() {
            root.syncKeyboardInteractivity()
        }
    }

    Connections {
        target: updateService
        function onUpdated() {
            root.syncKeyboardInteractivity()
        }
    }

    // Context menu
    ContextMenu {
        id: contextMenu
    }

    // Settings panel
    SettingsPanel {
        id: settingsPanel
        z: 300
        onIsOpenChanged: {
            root.syncKeyboardInteractivity()
        }
    }
}
