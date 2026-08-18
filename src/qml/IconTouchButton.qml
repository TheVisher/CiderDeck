import QtQuick

Rectangle {
    id: button

    signal clicked()

    property alias source: icon.source
    property color iconColor: themeManager.textColor
    property color activeColor: themeManager.accentColor
    property bool active: false
    property real iconSize: Math.min(width, height) * 0.42

    width: 52
    height: 52
    radius: 8
    color: active
           ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.22)
           : mouseArea.pressed
             ? Qt.rgba(1, 1, 1, 0.14)
             : mouseArea.containsMouse
               ? Qt.rgba(1, 1, 1, 0.09)
               : Qt.rgba(1, 1, 1, 0.055)
    border.width: 1
    border.color: active
                  ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.6)
                  : Qt.rgba(1, 1, 1, 0.09)
    opacity: enabled ? 1 : 0.35
    scale: mouseArea.pressed && enabled ? 0.94 : 1

    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 100 } }

    LucideIcon {
        id: icon
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        color: button.active ? button.activeColor : button.iconColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.clicked()
    }
}
