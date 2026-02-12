import QtQuick

Item {
    id: page

    required property int gridColumns
    required property int gridRows
    required property int gridGap
    required property int gridPadding
    required property real cellWidth
    required property real cellHeight

    Repeater {
        model: tileGridModel

        delegate: TileLoader {
            required property string tileId
            required property string tileType
            required property int col
            required property int row
            required property int colSpan
            required property int rowSpan
            required property string label
            required property bool showLabel
            required property real tileOpacity
            required property real tileBlurLevel
            required property var tileSettings

            tileIdValue: tileId
            tileTypeValue: tileType
            colValue: col
            rowValue: row
            colSpanValue: colSpan
            rowSpanValue: rowSpan
            labelValue: label
            showLabelValue: showLabel
            tileOpacityValue: tileOpacity
            tileBlurLevelValue: tileBlurLevel
            tileSettingsValue: tileSettings

            gridGap: page.gridGap
            gridPadding: page.gridPadding
            cellWidth: page.cellWidth
            cellHeight: page.cellHeight
        }
    }
}
