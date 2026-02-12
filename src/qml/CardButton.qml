import QtQuick

Card {
    id: cardButton

    signal clicked()
    signal pressAndHold()

    property bool pressAnimationEnabled: true
    property alias hovered: mouseArea.containsMouse

    scale: mouseArea.pressed && pressAnimationEnabled ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    // Hover overlay
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: themeManager.overlayColor
        visible: mouseArea.containsMouse && !mouseArea.pressed
    }

    // Press overlay
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(themeManager.overlayColor.r,
                       themeManager.overlayColor.g,
                       themeManager.overlayColor.b, 0.15)
        visible: mouseArea.pressed
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        pressAndHoldInterval: 500

        onClicked: cardButton.clicked()
        onPressAndHold: cardButton.pressAndHold()
    }
}
