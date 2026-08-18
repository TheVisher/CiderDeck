import QtQuick

CardButton {
    id: appTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1

    readonly property string desktopFile: settings.desktopFile || ""
    readonly property string command: settings.command || ""
    readonly property string iconOverride: settings.iconOverride || ""
    readonly property string targetMonitor: settings.targetMonitor || ""
    readonly property bool raiseExisting: settings.raiseExisting || false
    readonly property string wmClass: desktopFile ? appLaunchManager.wmClassForDesktop(desktopFile) : ""
    readonly property string iconSource: iconOverride
        ? "image://appicon/" + iconOverride
        : desktopFile
          ? "image://appicon/" + desktopFile
          : ""
    readonly property string displayLabel: {
        if (label && label !== "app_launcher") return label
        if (desktopFile) return appLaunchManager.appNameForDesktop(desktopFile)
        return ""
    }
    readonly property real iconSize: Math.min(width * 0.78,
                                               height * 0.66,
                                               78 * contentScale)
    property bool isRunning: false

    function updateRunning() {
        isRunning = wmClass !== "" && kwinClient.isAppRunning(wmClass)
    }

    pressAnimationEnabled: !contentEditMode
    onClicked: {
        if (!contentEditMode)
            appLaunchManager.launch(desktopFile, command, targetMonitor, raiseExisting)
    }
    Component.onCompleted: updateRunning()

    Connections {
        target: kwinClient
        function onWindowsChanged() { appTile.updateRunning() }
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 10

        Item {
            id: iconItem
            width: appTile.iconSize * contentLayout.elementScale("icon")
            height: width
            x: contentLayout.hasSavedValue("icon", "x")
               ? contentLayout.elementX("icon") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("icon", "y")
               ? contentLayout.elementY("icon")
               : (contentCanvas.height - height
                  - (labelItem.visible ? labelItem.height + 8 : 0)) / 2
            visible: appTile.iconSource !== "" && contentLayout.elementVisible("icon")
            z: appTile.selectedElement === "icon" ? 20 : 1

            Image {
                anchors.fill: parent
                source: appTile.iconSource
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            ContentEditableFrame { host: contentLayout; elementId: "icon" }
        }

        Item {
            id: labelItem
            width: Math.min(labelText.implicitWidth, contentCanvas.width)
            height: labelText.implicitHeight
            x: contentLayout.hasSavedValue("label", "x")
               ? contentLayout.elementX("label") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("label", "y")
               ? contentLayout.elementY("label") : iconItem.y + iconItem.height + 8
            visible: appTile.showLabel && appTile.displayLabel !== ""
                     && contentLayout.elementVisible("label")
            z: appTile.selectedElement === "label" ? 20 : 1

            Text {
                id: labelText
                width: parent.width
                text: appTile.displayLabel
                color: themeManager.textColor
                font.pixelSize: 12 * appTile.contentScale
                                * contentLayout.elementFontScale("label")
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "label" }
        }

        Item {
            id: statusItem
            width: 9 * appTile.contentScale * contentLayout.elementScale("status")
            height: width
            x: contentLayout.hasSavedValue("status", "x")
               ? contentLayout.elementX("status") : contentCanvas.width - width
            y: contentLayout.hasSavedValue("status", "y")
               ? contentLayout.elementY("status") : 0
            visible: (appTile.isRunning || appTile.contentEditMode)
                     && contentLayout.elementVisible("status")
            z: appTile.selectedElement === "status" ? 20 : 2

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: themeManager.successColor
                border.width: Math.max(1, 2 * appTile.contentScale)
                border.color: themeManager.backgroundColor
            }
            ContentEditableFrame { host: contentLayout; elementId: "status" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: appTile
        canvas: contentCanvas
        tileId: appTile.tileId
        settings: appTile.settings
        contentEditMode: appTile.contentEditMode
        selectedElement: appTile.selectedElement
        contentScale: appTile.contentScale
        elements: [
            { id: "icon", label: "Icon", scale: 1, textScale: 1,
              visible: true, hasText: false, globalGrowth: "sqrt" },
            { id: "label", label: "Label", scale: 1, textScale: 1,
              visible: true, hasText: true },
            { id: "status", label: "Running indicator", scale: 1, textScale: 1,
              visible: true, hasText: false }
        ]
        itemForId: function(elementId) {
            if (elementId === "icon") return iconItem
            if (elementId === "label") return labelItem
            if (elementId === "status") return statusItem
            return null
        }
    }
}
