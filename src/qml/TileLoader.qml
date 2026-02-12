import QtQuick

Item {
    id: tileLoader

    // Tile data (passed from delegate)
    property string tileIdValue
    property string tileTypeValue
    property int colValue
    property int rowValue
    property int colSpanValue
    property int rowSpanValue
    property string labelValue
    property bool showLabelValue
    property real tileOpacityValue
    property real tileBlurLevelValue
    property var tileSettingsValue

    // Grid properties
    property int gridGap
    property int gridPadding
    property real cellWidth
    property real cellHeight

    // Computed position and size
    x: gridPadding + colValue * (cellWidth + gridGap)
    y: gridPadding + rowValue * (cellHeight + gridGap)
    width: cellWidth * colSpanValue + gridGap * (colSpanValue - 1)
    height: cellHeight * rowSpanValue + gridGap * (rowSpanValue - 1)

    // Tile-specific opacity (passed to Card background, NOT the whole tile)
    readonly property real effectiveOpacity: tileOpacityValue >= 0 ? tileOpacityValue : deckConfig.globalOpacity

    // Size class for adaptive tiles
    readonly property string sizeClass: {
        if (width < 200 || height < 200) return "tiny"
        if (width < 400 || height < 300) return "small"
        if (width < 700) return "medium"
        return "large"
    }

    // Right-click context menu on tile
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: 1
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.targetTileId = tileLoader.tileIdValue
                let globalPos = mapToItem(null, mouse.x, mouse.y)
                contextMenu.popup(globalPos.x, globalPos.y)
            }
        }
    }

    Loader {
        id: contentLoader
        anchors.fill: parent

        sourceComponent: {
            switch (tileLoader.tileTypeValue) {
            case "clock_date":      return clockDateComponent
            case "app_launcher":    return appLauncherComponent
            case "command_button":  return commandButtonComponent
            case "media_player":    return mediaPlayerComponent
            case "volume":          return volumeComponent
            case "weather":         return weatherComponent
            case "system_monitor":  return systemMonitorComponent
            case "process_manager": return processManagerComponent
            case "screenshot":      return screenshotComponent
            case "brightness":      return brightnessComponent
            case "clipboard":       return clipboardComponent
            case "timer_stopwatch": return timerComponent
            default:                return placeholderComponent
            }
        }

        property string tileId: tileLoader.tileIdValue
        property string tileType: tileLoader.tileTypeValue
        property string label: tileLoader.labelValue
        property bool showLabel: tileLoader.showLabelValue
        property var settings: tileLoader.tileSettingsValue
        property string sizeClass: tileLoader.sizeClass
        property real tileWidth: tileLoader.width
        property real tileHeight: tileLoader.height
        property real cardOpacity: tileLoader.effectiveOpacity
    }

    // Edit overlay
    EditOverlay {
        anchors.fill: parent
        editMode: editController.editing
        tileId: tileLoader.tileIdValue
        colValue: tileLoader.colValue
        rowValue: tileLoader.rowValue
        colSpanValue: tileLoader.colSpanValue
        rowSpanValue: tileLoader.rowSpanValue
    }

    // Tile type components
    Component { id: clockDateComponent;     ClockDateTile {} }
    Component { id: appLauncherComponent;   AppLauncherTile {} }
    Component { id: commandButtonComponent; CommandButtonTile {} }

    // Placeholder for tiles not yet implemented
    Component {
        id: placeholderComponent
        Card {
            Text {
                anchors.centerIn: parent
                text: tileLoader.tileTypeValue
                color: themeManager.textColor
                font.pixelSize: 14
            }
        }
    }

    Component { id: mediaPlayerComponent;    MediaPlayerTile {} }
    Component { id: volumeComponent;         VolumeTile {} }
    Component { id: weatherComponent;        WeatherTile {} }
    Component { id: systemMonitorComponent;  SystemMonitorTile {} }
    Component { id: processManagerComponent; ProcessManagerTile {} }
    Component { id: screenshotComponent;     ScreenshotTile {} }
    Component { id: brightnessComponent;     BrightnessTile {} }
    Component { id: clipboardComponent;      ClipboardHistoryTile {} }
    Component { id: timerComponent;          TimerStopwatchTile {} }
}
