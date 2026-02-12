import QtQuick
import QtQuick.Window

Window {
    id: root

    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    // Full screen on the target display
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

    // Dashboard page (single page for now, multi-page in Phase 2)
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
}
