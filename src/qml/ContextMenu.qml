import QtQuick
import QtQuick.Controls

Menu {
    id: contextMenu

    property string targetTileId: ""
    property bool onTile: targetTileId !== ""

    // Tile-specific items
    MenuItem {
        text: "Edit Tile Settings"
        visible: contextMenu.onTile
        height: visible ? implicitHeight : 0
        onTriggered: {
            settingsPanel.openTile(contextMenu.targetTileId)
        }
    }

    MenuItem {
        text: "Delete Tile"
        visible: contextMenu.onTile
        height: visible ? implicitHeight : 0
        onTriggered: {
            editController.deleteTile(contextMenu.targetTileId)
            toastModel.showWithAction("Tile deleted", "Undo", "undo_delete", 5000)
        }
    }

    MenuSeparator {
        visible: contextMenu.onTile
        height: visible ? implicitHeight : 0
    }

    // Space items
    Menu {
        title: "Add Tile"

        MenuItem { text: "App Launcher";    onTriggered: editController.addTile("app_launcher") }
        MenuItem { text: "Media Player";    onTriggered: editController.addTile("media_player") }
        MenuItem { text: "Volume";          onTriggered: editController.addTile("volume") }
        MenuItem { text: "Clock/Date";      onTriggered: editController.addTile("clock_date") }
        MenuItem { text: "Weather";         onTriggered: editController.addTile("weather") }
        MenuItem { text: "System Monitor";  onTriggered: editController.addTile("system_monitor") }
        MenuItem { text: "Process Manager"; onTriggered: editController.addTile("process_manager") }
        MenuItem { text: "Screenshot";      onTriggered: editController.addTile("screenshot") }
        MenuItem { text: "Brightness";      onTriggered: editController.addTile("brightness") }
        MenuItem { text: "Clipboard";       onTriggered: editController.addTile("clipboard") }
        MenuItem { text: "Timer/Stopwatch"; onTriggered: editController.addTile("timer_stopwatch") }
        MenuItem { text: "Command Button";  onTriggered: editController.addTile("command_button") }
    }

    MenuItem {
        text: editController.editing ? "Done Editing" : "Edit Mode"
        onTriggered: editController.toggleEditMode()
    }

    MenuSeparator {}

    MenuItem {
        text: "Add Page"
        onTriggered: deckConfig.addPage()
    }

    MenuItem {
        text: "App Settings"
        onTriggered: {
            settingsPanel.openGeneral()
        }
    }
}
