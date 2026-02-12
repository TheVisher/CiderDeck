import QtQuick

Item {
    id: toastStack

    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 16
    width: parent.width
    height: toastColumn.height

    Column {
        id: toastColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Repeater {
            model: toastModel

            delegate: Toast {
                toastId: model.toastId
                message: model.message
                actionLabel: model.actionLabel
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                onActionClicked: toastModel.triggerAction(model.toastId)
                onDismissed: toastModel.dismiss(model.toastId)
            }
        }
    }
}
