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

    // Move to page items — generated dynamically at open time.
    // We avoid sub-Menu with visible binding: Qt Quick Controls crashes
    // when a sub-Menu's visibility changes before the parent is open.

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
        MenuItem { text: "Show Desktop";   onTriggered: editController.addTile("show_desktop") }
        MenuItem { text: "Overview";       onTriggered: editController.addTile("overview") }
        MenuItem { text: "Audio Mixer";    onTriggered: editController.addTile("audio_mixer") }
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
        text: "Delete Page"
        enabled: deckConfig.pageCount > 1
        onTriggered: {
            deckConfig.removePage(deckConfig.currentPage)
        }
    }

    MenuItem {
        text: "App Settings"
        onTriggered: {
            settingsPanel.openGeneral()
        }
    }

    // Inject "Move to Page N" items when the menu opens
    function rebuildMoveItems() {
        // Remove previously injected items (tagged with _isMoveItem)
        for (var i = contextMenu.count - 1; i >= 0; i--) {
            var existing = contextMenu.itemAt(i)
            if (existing && existing._isMoveItem) {
                contextMenu.takeItem(i).destroy()
            }
        }

        // Only add when right-clicking a tile and there are multiple pages
        if (!contextMenu.onTile || deckConfig.pageCount < 2)
            return

        // Find the separator after Delete Tile (index 2) to insert after it
        // Items: 0=Edit, 1=Delete, 2=Separator, 3+=rest
        var insertAt = 3
        var names = deckConfig.pageNames()
        for (var j = 0; j < names.length; j++) {
            if (j === deckConfig.currentPage)
                continue
            var item = moveItemComp.createObject(contextMenu, {
                pageIdx: j,
                pageName: names[j]
            })
            contextMenu.insertItem(insertAt, item)
            insertAt++
        }
    }

    onAboutToShow: rebuildMoveItems()

    // Factory — declared as property, not a Menu child
    property Component moveItemComp: Component {
        MenuItem {
            property bool _isMoveItem: true
            property int pageIdx: 0
            property string pageName: ""
            text: "Move to " + pageName
            onTriggered: {
                var ok = deckConfig.moveTileToPage(contextMenu.targetTileId, pageIdx)
                if (ok) {
                    toastModel.show("Moved to " + pageName, 3000)
                } else {
                    toastModel.show("No room on " + pageName, 3000)
                }
            }
        }
    }
}
