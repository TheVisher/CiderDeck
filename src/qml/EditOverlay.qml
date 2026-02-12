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

        Text {
            anchors.centerIn: parent
            text: "\u00D7"
            color: "white"
            font.pixelSize: 16
            font.bold: true
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

        // Three diagonal lines to indicate resize
        Column {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    width: 10 - index * 3
                    height: 2
                    color: "white"
                    x: index * 3
                }
            }
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

    // Drag handler on the main tile body
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: 20
        z: 5
        preventStealing: true
        enabled: overlay.editMode

        onPressed: (mouse) => {
            editController.beginDrag(overlay.tileId, overlay.colValue, overlay.rowValue,
                                      overlay.colSpanValue, overlay.rowSpanValue)
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
