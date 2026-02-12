import QtQuick

Item {
    id: toastStack

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 16
    width: parent.width
    height: toastColumn.height

    Column {
        id: toastColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Repeater {
            model: toastModel

            delegate: Toast {
                required property string toastId
                required property string message
                required property string actionLabel

                toastId: toastId
                message: message
                actionLabel: actionLabel
                anchors.horizontalCenter: parent.horizontalCenter

                onActionClicked: toastModel.triggerAction(toastId)
                onDismissed: toastModel.dismiss(toastId)
            }
        }
    }
}
