import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property alias source: img.source
    property color color: "white"

    Image {
        id: img
        anchors.fill: parent
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectFit
        visible: false
        smooth: true
    }

    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.color
    }
}
