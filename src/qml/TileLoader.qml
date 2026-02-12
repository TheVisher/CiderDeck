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

    // Effective opacity (use tile-specific or global)
    opacity: tileOpacityValue >= 0 ? tileOpacityValue : deckConfig.globalOpacity

    // Size class for adaptive tiles
    readonly property string sizeClass: {
        if (width < 200 || height < 200) return "tiny"
        if (width < 400 || height < 300) return "small"
        if (width < 700) return "medium"
        return "large"
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

    // Stubs for future tile types (Phase 3+4)
    Component { id: mediaPlayerComponent;    Card { Text { anchors.centerIn: parent; text: "Media Player"; color: themeManager.textColor } } }
    Component { id: volumeComponent;         Card { Text { anchors.centerIn: parent; text: "Volume"; color: themeManager.textColor } } }
    Component { id: weatherComponent;        Card { Text { anchors.centerIn: parent; text: "Weather"; color: themeManager.textColor } } }
    Component { id: systemMonitorComponent;  Card { Text { anchors.centerIn: parent; text: "System Monitor"; color: themeManager.textColor } } }
    Component { id: processManagerComponent; Card { Text { anchors.centerIn: parent; text: "Processes"; color: themeManager.textColor } } }
    Component { id: screenshotComponent;     Card { Text { anchors.centerIn: parent; text: "Screenshot"; color: themeManager.textColor } } }
    Component { id: brightnessComponent;     Card { Text { anchors.centerIn: parent; text: "Brightness"; color: themeManager.textColor } } }
    Component { id: clipboardComponent;      Card { Text { anchors.centerIn: parent; text: "Clipboard"; color: themeManager.textColor } } }
    Component { id: timerComponent;          Card { Text { anchors.centerIn: parent; text: "Timer"; color: themeManager.textColor } } }
}
