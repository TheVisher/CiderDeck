import QtQuick
import QtQuick.Window

Window {
    id: root

    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    width: Screen.width
    height: Screen.height
    x: Screen.virtualX
    y: Screen.virtualY

    title: "CiderDeck"

    // Grid math helpers
    readonly property int gridColumns: deckConfig.gridColumns
    readonly property int gridRows: deckConfig.gridRows
    readonly property int gridGap: deckConfig.gridGap
    readonly property int gridPadding: deckConfig.padding
    readonly property real cellWidth: (width - gridPadding * 2 - gridGap * (gridColumns - 1)) / gridColumns
    readonly property real cellHeight: (height - gridPadding * 2 - gridGap * (gridRows - 1)) / gridRows

    // Background touch area for context menu and edit mode exit
    MouseArea {
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

    // Dashboard page
    DashboardPage {
        id: dashboard
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

    // Page dots
    PageDots {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 6
        pageCount: deckConfig.pageCount
        currentPage: deckConfig.currentPage
        z: 50
    }

    // Toast stack
    ToastStack {
        z: 200
    }

    // Context menu
    ContextMenu {
        id: contextMenu
    }

    // Settings panel
    SettingsPanel {
        id: settingsPanel
        z: 300
    }
}
