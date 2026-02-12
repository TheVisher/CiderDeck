import QtQuick

Card {
    id: clipTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Text {
            text: "Clipboard"
            color: themeManager.textColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            visible: clipTile.sizeClass !== "tiny"
        }

        ListView {
            id: clipList
            width: parent.width
            height: parent.height - (clipTile.sizeClass !== "tiny" ? 20 : 0)
            model: clipboardService
            clip: true
            spacing: 2

            delegate: Rectangle {
                required property string text
                required property string timestamp
                required property int index

                width: clipList.width
                height: 24
                radius: 4
                color: clipMouseArea.containsMouse ? themeManager.overlayColor : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 6

                    Text {
                        text: timestamp
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: clipTile.sizeClass !== "tiny" && clipTile.sizeClass !== "small"
                    }

                    Text {
                        text: parent.parent.text.replace(/\n/g, " ")
                        color: themeManager.textColor
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width - 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: clipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: clipboardService.copyToClipboard(index)
                }
            }
        }
    }
}
