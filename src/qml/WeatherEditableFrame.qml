import QtQuick

Item {
    id: frame

    required property var host
    required property string elementId

    anchors.fill: parent
    visible: host.contentEditMode
    z: 100

    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        radius: 5
        color: "transparent"
        border.width: 2
        border.color: host.dragElementId === frame.elementId && !host.dragValid
                      ? themeManager.errorColor
                      : host.selectedElement === frame.elementId
                        ? themeManager.accentColor
                        : Qt.rgba(1, 1, 1, 0.38)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: 5
        height: 18
        width: elementLabel.implicitWidth + 10
        radius: 4
        color: host.selectedElement === frame.elementId
               ? themeManager.accentColor : Qt.rgba(0.08, 0.10, 0.15, 0.92)

        Text {
            id: elementLabel
            anchors.centerIn: parent
            text: host.elementDisplayName(frame.elementId)
            color: "white"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -7
        preventStealing: true

        onPressed: (mouse) => {
            var point = mapToItem(host.contentCanvas, mouse.x, mouse.y)
            host.beginElementDrag(frame.elementId, frame.parent, point.x, point.y)
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            var point = mapToItem(host.contentCanvas, mouse.x, mouse.y)
            host.updateElementDrag(point.x, point.y)
        }
        onReleased: host.endElementDrag()
        onCanceled: host.cancelElementDrag()
    }
}
