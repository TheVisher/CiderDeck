import QtQuick

Rectangle {
    id: toast

    property string toastId: ""
    property string message: ""
    property string actionLabel: ""

    signal actionClicked()
    signal dismissed()

    width: toastRow.width + 32
    height: 44
    radius: 22
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b, 0.92)
    border.width: 1
    border.color: themeManager.borderColor

    // Slide-in animation
    opacity: 0
    y: 20
    Component.onCompleted: {
        opacity = 1
        y = 0
    }
    Behavior on opacity { NumberAnimation { duration: 200 } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: toastRow
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: toast.message
            color: themeManager.textColor
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        // Action button (e.g., "Undo")
        Rectangle {
            visible: toast.actionLabel !== ""
            width: actionText.width + 16
            height: 28
            radius: 14
            color: themeManager.accentColor
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: actionText
                anchors.centerIn: parent
                text: toast.actionLabel
                color: "white"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: toast.actionClicked()
            }
        }
    }

    // Tap to dismiss
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: toast.dismissed()
    }
}
