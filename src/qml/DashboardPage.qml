import QtQuick

Item {
    id: page

    required property int pageIndex
    required property int gridColumns
    required property int gridRows
    required property int gridGap
    required property int gridPadding
    required property real cellWidth
    required property real cellHeight
    property int tileRevision: 0
    readonly property bool activePage: pageIndex === deckConfig.currentPage
    readonly property var pageTiles: {
        tileRevision
        return deckConfig.tilesForPage(pageIndex)
    }

    Connections {
        target: deckConfig
        function onTilesChanged() { page.tileRevision++ }
        function onConfigLoaded() { page.tileRevision++ }
    }

    Repeater {
        model: page.pageTiles

        delegate: TileLoader {
            required property var modelData

            tileIdValue: modelData.id || ""
            tileTypeValue: modelData.type || ""
            colValue: modelData.col || 0
            rowValue: modelData.row || 0
            colSpanValue: modelData.colSpan || 1
            rowSpanValue: modelData.rowSpan || 1
            labelValue: modelData.label || ""
            showLabelValue: modelData.showLabel !== false
            tileOpacityValue: modelData.opacity !== undefined ? modelData.opacity : -1
            tileBlurLevelValue: modelData.blurLevel !== undefined ? modelData.blurLevel : -1
            tileSettingsValue: modelData.settings || ({})
            monitoringActive: page.activePage

            gridGap: page.gridGap
            gridPadding: page.gridPadding
            cellWidth: page.cellWidth
            cellHeight: page.cellHeight
        }
    }
}
