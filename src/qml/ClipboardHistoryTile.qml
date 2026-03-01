import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: clipTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property bool showHeader: settings.showHeader !== false
    readonly property bool showTimestamps: settings.showTimestamps !== false
    readonly property bool showScrollbar: settings.showScrollbar !== false
    readonly property real thumbnailHeight: (settings.thumbnailHeight || 80) * contentScale
    readonly property real sp: 4 * contentScale

    Item {
        anchors.fill: parent
        anchors.margins: 8

        // Header
        Text {
            id: headerText
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            text: "Clipboard"
            color: themeManager.textColor
            font.pixelSize: 14 * clipTile.contentScale
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            visible: clipTile.showHeader
        }

        Rectangle {
            id: headerSep
            anchors.top: clipTile.showHeader ? headerText.bottom : parent.top
            anchors.topMargin: clipTile.showHeader ? clipTile.sp : 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: clipTile.showHeader ? 1 : 0
            color: themeManager.borderColor
            visible: clipTile.showHeader
        }

        // Clear button at bottom
        Item {
            id: clearContainer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: clipboardService.count > 0 ? clearBtn.height + clipTile.sp : 0
            visible: clipboardService.count > 0

            Rectangle {
                id: clearBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 28 * clipTile.contentScale
                height: 28 * clipTile.contentScale
                radius: width / 2
                color: clearArea.containsMouse ? themeManager.overlayColor : "transparent"

                LucideIcon {
                    anchors.centerIn: parent
                    width: 16 * clipTile.contentScale
                    height: 16 * clipTile.contentScale
                    source: "qrc:/icons/lucide/trash-2.svg"
                    color: clearArea.containsMouse ? themeManager.errorColor : themeManager.secondaryTextColor
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: clipboardService.clear()
                }
            }
        }

        // Scrollable list (fills space between header and clear button)
        ListView {
            id: clipList
            anchors.top: headerSep.visible ? headerSep.bottom : parent.top
            anchors.topMargin: clipTile.sp
            anchors.bottom: clearContainer.visible ? clearContainer.top : parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            model: clipboardService
            clip: true
            spacing: clipTile.sp

            delegate: Rectangle {
                id: clipDelegate
                required property string text
                required property string timestamp
                required property bool isImage
                required property int index
                required property var entryId

                width: clipList.width
                height: delegateContent.implicitHeight + 8 * clipTile.contentScale
                radius: 6
                color: clipMouseArea.containsMouse ? themeManager.overlayColor : "transparent"

                Column {
                    id: delegateContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4 * clipTile.contentScale
                    spacing: 2 * clipTile.contentScale

                    // Timestamp
                    Text {
                        text: clipDelegate.timestamp
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 10 * clipTile.contentScale
                        visible: clipTile.showTimestamps
                    }

                    // Image thumbnail
                    Image {
                        visible: clipDelegate.isImage
                        source: clipDelegate.isImage
                                ? "image://clipboard/" + clipDelegate.entryId
                                : ""
                        width: parent.width
                        height: clipTile.thumbnailHeight
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        cache: false
                    }

                    // Text content — wraps up to 3 lines then elides
                    Text {
                        visible: !clipDelegate.isImage
                        text: clipDelegate.text
                        color: themeManager.textColor
                        font.pixelSize: 13 * clipTile.contentScale
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                MouseArea {
                    id: clipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: clipboardService.copyToClipboard(clipDelegate.index)
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: clipTile.showScrollbar && clipList.contentHeight > clipList.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            text: "No clipboard history"
            color: themeManager.secondaryTextColor
            font.pixelSize: 12 * clipTile.contentScale
            visible: clipboardService.count === 0
        }
    }
}
