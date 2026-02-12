import QtQuick
import QtQuick.Controls

SwipeView {
    id: pageSwipe

    property int gridColumns
    property int gridRows
    property int gridGap
    property int gridPadding
    property real cellWidth
    property real cellHeight

    currentIndex: deckConfig.currentPage
    onCurrentIndexChanged: deckConfig.currentPage = currentIndex

    clip: true

    Repeater {
        model: deckConfig.pageCount

        delegate: DashboardPage {
            required property int index

            gridColumns: pageSwipe.gridColumns
            gridRows: pageSwipe.gridRows
            gridGap: pageSwipe.gridGap
            gridPadding: pageSwipe.gridPadding
            cellWidth: pageSwipe.cellWidth
            cellHeight: pageSwipe.cellHeight

            Component.onCompleted: {
                // Ensure the grid model tracks the correct page for this delegate
                if (index === deckConfig.currentPage) {
                    tileGridModel.currentPage = index
                }
            }
        }
    }
}
