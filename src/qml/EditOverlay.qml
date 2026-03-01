import QtQuick

Item {
    id: overlay

    property bool editMode: false
    property string tileId: ""
    property int colValue: 0
    property int rowValue: 0
    property int colSpanValue: 1
    property int rowSpanValue: 1

    visible: editMode

    // Delete button (top-left)
    Rectangle {
        id: deleteButton
        width: 24
        height: 24
        radius: 12
        color: "#e53935"
        x: -8
        y: -8
        z: 10

        LucideIcon {
            anchors.centerIn: parent
            width: 14; height: 14
            source: "qrc:/icons/lucide/x.svg"
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                editController.deleteTile(overlay.tileId)
                toastModel.showWithAction("Tile deleted", "Undo", "undo_delete_" + overlay.tileId, 5000)
            }
        }
    }

    // Resize handle (bottom-right)
    Rectangle {
        id: resizeHandle
        width: 24
        height: 24
        radius: 4
        color: themeManager.accentColor
        opacity: 0.8
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -4
        anchors.bottomMargin: -4
        z: 10

        LucideIcon {
            anchors.centerIn: parent
            width: 14; height: 14
            source: "qrc:/icons/lucide/maximize-2.svg"
            color: "white"
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            preventStealing: true

            onPressed: (mouse) => {
                editController.beginResize(overlay.tileId, overlay.colValue, overlay.rowValue,
                                            overlay.colSpanValue, overlay.rowSpanValue)
            }

            onPositionChanged: (mouse) => {
                let globalPos = resizeArea.mapToItem(null, mouse.x, mouse.y)
                editController.updateResize(globalPos.x, globalPos.y,
                                             root.cellWidth, root.cellHeight,
                                             root.gridGap, root.gridPadding)
            }

            onReleased: {
                editController.endResize()
            }
        }
    }

    // Per-tile center crosshair (white to distinguish from grid center lines)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 1
        color: "#ffffff"
        opacity: 0.12
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 1
        color: "#ffffff"
        opacity: 0.12
    }

    // Drag handler on the main tile body
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: 20
        z: 5
        preventStealing: true
        enabled: overlay.editMode

        onPressed: (mouse) => {
            let globalPos = dragArea.mapToItem(null, mouse.x, mouse.y)
            editController.beginDrag(overlay.tileId, overlay.colValue, overlay.rowValue,
                                      overlay.colSpanValue, overlay.rowSpanValue,
                                      globalPos.x, globalPos.y,
                                      root.cellWidth, root.cellHeight,
                                      root.gridGap, root.gridPadding)
        }

        onPositionChanged: (mouse) => {
            let globalPos = dragArea.mapToItem(null, mouse.x, mouse.y)
            editController.updateDrag(globalPos.x, globalPos.y,
                                       root.cellWidth, root.cellHeight,
                                       root.gridGap, root.gridPadding)
        }

        onReleased: {
            editController.endDrag()
        }
    }
}
