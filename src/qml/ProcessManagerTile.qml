import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: procTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property bool showMemory: settings.showMemory !== false
    readonly property bool allowTerminate: settings.allowTerminate === true
    readonly property int maxProcesses: settings.maxProcesses || 15

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "PROCESSES · TOP MEMORY"
            color: themeManager.textColor
            font.pixelSize: 13 * procTile.contentScale
            font.weight: Font.DemiBold
            visible: procTile.sizeClass !== "tiny"
        }

        GridView {
            id: procList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: processManager
            clip: true
            interactive: false
            readonly property int columnCount: width >= 700 ? 3 : (width >= 440 ? 2 : 1)
            cellWidth: width / columnCount
            cellHeight: 44 * procTile.contentScale

            delegate: Rectangle {
                required property int index
                required property string name
                required property int pid
                required property string memory
                required property bool unresponsive

                width: procList.cellWidth - 10
                height: procList.cellHeight - 6
                visible: index < procTile.maxProcesses
                radius: 6
                color: themeManager.overlayColor
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 2
                    color: parent.unresponsive ? themeManager.errorColor : themeManager.accentColor
                    opacity: parent.unresponsive ? 1.0 : 0.75
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: procTile.allowTerminate ? 30 : 10
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: name
                        color: themeManager.textColor
                        font.pixelSize: 12 * procTile.contentScale
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: unresponsive ? "Not responding · " + memory : memory
                        color: unresponsive ? themeManager.errorColor : themeManager.secondaryTextColor
                        font.pixelSize: 11 * procTile.contentScale
                        visible: procTile.showMemory && procTile.sizeClass !== "small"
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: themeManager.errorColor
                    opacity: 0.75
                    visible: procTile.allowTerminate
                             && (procTile.sizeClass === "medium" || procTile.sizeClass === "large")

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        source: "qrc:/icons/lucide/x.svg"
                        color: "white"
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
