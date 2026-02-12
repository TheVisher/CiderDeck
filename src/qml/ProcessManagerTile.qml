import QtQuick
import QtQuick.Controls

Card {
    id: procTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Text {
            text: "Processes"
            color: themeManager.textColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            visible: procTile.sizeClass !== "tiny"
        }

        ListView {
            id: procList
            width: parent.width
            height: parent.height - (procTile.sizeClass !== "tiny" ? 20 : 0)
            model: processManager
            clip: true
            spacing: 2

            delegate: Rectangle {
                required property string name
                required property int pid
                required property string memory

                width: procList.width
                height: 22
                radius: 4
                color: "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 8

                    Text {
                        text: name
                        color: themeManager.textColor
                        font.pixelSize: 11
                        width: parent.width * 0.5
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: memory
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 10
                        width: parent.width * 0.25
                        anchors.verticalCenter: parent.verticalCenter
                        visible: procTile.sizeClass !== "small"
                    }

                    // Kill button
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: themeManager.errorColor
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                        visible: procTile.sizeClass === "medium" || procTile.sizeClass === "large"

                        Text {
                            anchors.centerIn: parent
                            text: "\u00D7"
                            color: "white"
                            font.pixelSize: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: processManager.killProcess(pid)
                        }
                    }
                }
            }
        }
    }
}
