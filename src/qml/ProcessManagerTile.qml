import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: procTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property bool monitoringActive: parent ? parent.monitoringActive : false
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property bool showMemory: settings.showMemory !== false
    readonly property bool allowTerminate: settings.allowTerminate === true
    readonly property int maxProcesses: settings.maxProcesses || 15

    Component.onCompleted: processManager.setConsumerActive(procTile, procTile.monitoringActive)
    onMonitoringActiveChanged: processManager.setConsumerActive(procTile, procTile.monitoringActive)

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 12

        Item {
            id: headerItem
            width: headerText.implicitWidth; height: headerText.implicitHeight
            x: contentLayout.hasSavedValue("header", "x")
               ? contentLayout.elementX("header") : 0
            y: contentLayout.hasSavedValue("header", "y")
               ? contentLayout.elementY("header") : 0
            visible: procTile.sizeClass !== "tiny" && contentLayout.elementVisible("header")
            z: procTile.selectedElement === "header" ? 20 : 1
            Text {
                id: headerText
                text: "PROCESSES · TOP MEMORY"
                color: themeManager.textColor
                font.pixelSize: 13 * procTile.contentScale
                                * contentLayout.elementFontScale("header")
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "header" }
        }

        GridView {
            id: procList
            x: contentLayout.hasSavedValue("processes", "x")
               ? contentLayout.elementX("processes") : 0
            y: contentLayout.hasSavedValue("processes", "y")
               ? contentLayout.elementY("processes") : (headerItem.visible ? headerItem.y + headerItem.height + 8 : 0)
            width: contentCanvas.width
            height: contentCanvas.height - y
            visible: contentLayout.elementVisible("processes")
            z: procTile.selectedElement === "processes" ? 20 : 1
            model: processManager
            clip: true
            interactive: false
            readonly property int columnCount: width >= 700 ? 3 : (width >= 440 ? 2 : 1)
            cellWidth: width / columnCount
            cellHeight: 44 * procTile.contentScale * contentLayout.elementScale("processes")

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
                    anchors.rightMargin: procTile.allowTerminate
                                         ? 10 + 20 * procTile.contentScale : 10
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: name
                        color: themeManager.textColor
                        font.pixelSize: 12 * procTile.contentScale
                                        * contentLayout.elementFontScale("processes")
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: unresponsive ? "Not responding · " + memory : memory
                        color: unresponsive ? themeManager.errorColor : themeManager.secondaryTextColor
                        font.pixelSize: 11 * procTile.contentScale
                                        * contentLayout.elementFontScale("processes")
                        visible: procTile.showMemory
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * procTile.contentScale
                    height: width
                    radius: width / 2
                    color: themeManager.errorColor
                    opacity: 0.75
                    visible: procTile.allowTerminate

                    LucideIcon {
                        anchors.centerIn: parent
                        width: 10 * procTile.contentScale
                        height: width
                        source: "qrc:/icons/lucide/x.svg"
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !procTile.contentEditMode
                        onClicked: processManager.killProcess(pid)
                    }
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "processes" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: procTile; canvas: contentCanvas; tileId: procTile.tileId
        settings: procTile.settings; contentEditMode: procTile.contentEditMode
        selectedElement: procTile.selectedElement; contentScale: procTile.contentScale
        elements: [
            { id: "header", label: "Header", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "processes", label: "Process list", scale: 1, textScale: 1, visible: true, hasText: true, globalGrowth: "none" }
        ]
        itemForId: function(elementId) {
            if (elementId === "header") return headerItem
            if (elementId === "processes") return procList
            return null
        }
    }
}
