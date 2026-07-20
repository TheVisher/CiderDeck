import QtQuick
import QtQuick.Controls

Card {
    id: clipTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property bool showHeader: settings.showHeader !== false
    readonly property bool showTimestamps: settings.showTimestamps !== false
    readonly property bool use24HourTime: (settings.timestampFormat || "12h") === "24h"
    readonly property bool showScrollbar: settings.showScrollbar !== false
    readonly property real thumbnailHeight: (settings.thumbnailHeight || 80) * contentScale
    readonly property real sp: 4 * contentScale

    Component.onCompleted: clipboardService.setMaxEntries(settings.maxEntries || 20)
    onSettingsChanged: clipboardService.setMaxEntries(settings.maxEntries || 20)

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 8

        Item {
            id: headerItem
            width: Math.min(headerText.implicitWidth, contentCanvas.width)
            height: headerText.implicitHeight + clipTile.sp + 1
            x: contentLayout.hasSavedValue("header", "x")
               ? contentLayout.elementX("header") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("header", "y")
               ? contentLayout.elementY("header") : 0
            visible: clipTile.showHeader && contentLayout.elementVisible("header")
            z: clipTile.selectedElement === "header" ? 20 : 2

            Text {
                id: headerText
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Clipboard"
                color: themeManager.textColor
                font.pixelSize: 14 * clipTile.contentScale
                                * contentLayout.elementFontScale("header")
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: themeManager.borderColor
            }
            ContentEditableFrame { host: contentLayout; elementId: "header" }
        }

        Item {
            id: clearItem
            readonly property real unit: 28 * clipTile.contentScale
                                         * contentLayout.elementScale("clear")
            width: unit; height: unit
            x: contentLayout.hasSavedValue("clear", "x")
               ? contentLayout.elementX("clear") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("clear", "y")
               ? contentLayout.elementY("clear") : contentCanvas.height - height
            visible: clipboardService.count > 0 && contentLayout.elementVisible("clear")
            z: clipTile.selectedElement === "clear" ? 20 : 2

            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: clearArea.containsMouse ? themeManager.overlayColor : "transparent"
                LucideIcon {
                    anchors.centerIn: parent; width: parent.width * 0.58; height: width
                    source: "qrc:/icons/lucide/trash-2.svg"
                    color: clearArea.containsMouse ? themeManager.errorColor : themeManager.secondaryTextColor
                }
                MouseArea {
                    id: clearArea
                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    enabled: !clipTile.contentEditMode
                    onClicked: clipboardService.clear()
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Clear KDE clipboard history"
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "clear" }
        }

        ListView {
            id: historyItem
            readonly property real entryScale: contentLayout.elementScale("history")
            x: contentLayout.hasSavedValue("history", "x")
               ? contentLayout.elementX("history") : 0
            y: contentLayout.hasSavedValue("history", "y")
               ? contentLayout.elementY("history") : (headerItem.visible ? headerItem.y + headerItem.height + Math.max(8, clipTile.sp) : 0)
            width: contentCanvas.width
            height: Math.max(1, (clearItem.visible ? clearItem.y - Math.max(8, clipTile.sp) : contentCanvas.height) - y)
            visible: clipboardService.count > 0 && contentLayout.elementVisible("history")
            z: clipTile.selectedElement === "history" ? 20 : 1
            model: clipboardService
            clip: true
            spacing: clipTile.sp * entryScale

            delegate: Rectangle {
                id: clipDelegate
                required property string text
                required property string timestamp
                required property double timestampEpoch
                required property bool isImage
                required property url imageSource
                required property int index
                width: historyItem.width
                height: delegateContent.implicitHeight
                        + 8 * clipTile.contentScale * historyItem.entryScale
                radius: 6
                color: clipMouseArea.containsMouse ? themeManager.overlayColor : "transparent"

                Column {
                    id: delegateContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 4 * clipTile.contentScale * historyItem.entryScale
                    spacing: 2 * clipTile.contentScale * historyItem.entryScale
                    Text {
                        text: Qt.formatTime(new Date(clipDelegate.timestampEpoch * 1000),
                                            clipTile.use24HourTime
                                            ? "HH:mm" : "h:mm AP")
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 10 * clipTile.contentScale
                                        * contentLayout.elementTextScale("history")
                        visible: clipTile.showTimestamps
                        renderType: Text.NativeRendering
                    }
                    Image {
                        visible: clipDelegate.isImage; source: clipDelegate.imageSource
                        width: parent.width
                        height: clipTile.thumbnailHeight * historyItem.entryScale
                        fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft
                        cache: false
                    }
                    Text {
                        visible: !clipDelegate.isImage; text: clipDelegate.text
                        color: themeManager.textColor
                        font.pixelSize: 13 * clipTile.contentScale
                                        * contentLayout.elementTextScale("history")
                        wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        width: parent.width; renderType: Text.NativeRendering
                    }
                }
                MouseArea {
                    id: clipMouseArea
                    anchors.fill: parent; hoverEnabled: true
                    enabled: !clipTile.contentEditMode
                    onClicked: clipboardService.copyToClipboard(clipDelegate.index)
                }
            }
            ScrollBar.vertical: ScrollBar {
                policy: clipTile.showScrollbar && historyItem.contentHeight > historyItem.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
            ContentEditableFrame { host: contentLayout; elementId: "history" }
        }

        Item {
            id: emptyItem
            width: emptyText.implicitWidth; height: emptyText.implicitHeight
            x: contentLayout.hasSavedValue("empty", "x")
               ? contentLayout.elementX("empty") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("empty", "y")
               ? contentLayout.elementY("empty") : (contentCanvas.height - height) / 2
            visible: clipboardService.count === 0 && contentLayout.elementVisible("empty")
            z: clipTile.selectedElement === "empty" ? 20 : 1
            Text {
                id: emptyText; text: "No clipboard history"
                color: themeManager.secondaryTextColor
                font.pixelSize: 12 * clipTile.contentScale
                                * contentLayout.elementFontScale("empty")
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "empty" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: clipTile; canvas: contentCanvas; tileId: clipTile.tileId
        settings: clipTile.settings; contentEditMode: clipTile.contentEditMode
        selectedElement: clipTile.selectedElement; contentScale: clipTile.contentScale
        guardGlobalScale: false
        elements: [
            { id: "header", label: "Header", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "history", label: "History", scale: 1, textScale: 1,
              visible: true, hasText: true, globalGrowth: "none",
              itemGrowth: "none", textGrowth: "none", skipCollision: true },
            { id: "clear", label: "Clear button", scale: 1, textScale: 1, visible: true, hasText: false, globalGrowth: "sqrt" },
            { id: "empty", label: "Empty message", scale: 1, textScale: 1, visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "header") return headerItem
            if (elementId === "history") return historyItem
            if (elementId === "clear") return clearItem
            if (elementId === "empty") return emptyItem
            return null
        }
    }
}
