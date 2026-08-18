import QtQuick

CardButton {
    id: screenshotTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property real pad: 12
    readonly property real baseIconSize: {
        var base
        switch (sizeClass) {
        case "tiny":  base = Math.min(width, height) * 0.5; break
        case "small": base = Math.min(width, height) * 0.4; break
        default:      base = 40; break
        }
        var textRoom = (labelItem.visible ? labelItem.height + 6 : 0)
                     + (shortcutItem.visible ? shortcutItem.height + 6 : 0)
        return Math.max(12, Math.min(base * contentScale,
                                     width - pad * 2, height - pad * 2 - textRoom))
    }

    pressAnimationEnabled: !contentEditMode
    onClicked: {
        if (!contentEditMode) screenshotService.triggerShortcut()
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: screenshotTile.pad

        Item {
            id: iconItem
            width: screenshotTile.baseIconSize * contentLayout.elementScale("icon")
            height: width
            x: contentLayout.hasSavedValue("icon", "x")
               ? contentLayout.elementX("icon") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("icon", "y")
               ? contentLayout.elementY("icon")
               : (contentCanvas.height - height
                  - (labelItem.visible ? labelItem.height + 6 : 0)
                  - (shortcutItem.visible ? shortcutItem.height + 6 : 0)) / 2
            visible: contentLayout.elementVisible("icon")
            z: screenshotTile.selectedElement === "icon" ? 20 : 1

            LucideIcon {
                anchors.fill: parent
                source: "qrc:/icons/lucide/camera.svg"
                color: themeManager.textColor
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
               ? contentLayout.elementY("label") : iconItem.y + iconItem.height + 6
            visible: screenshotTile.showLabel && screenshotTile.sizeClass !== "tiny"
                     && contentLayout.elementVisible("label")
            z: screenshotTile.selectedElement === "label" ? 20 : 1

            Text {
                id: labelText
                width: parent.width
                text: screenshotTile.label || "Screenshot"
                color: themeManager.textColor
                font.pixelSize: 12 * screenshotTile.contentScale
                                * contentLayout.elementFontScale("label")
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "label" }
        }

        Item {
            id: shortcutItem
            width: shortcutText.implicitWidth
            height: shortcutText.implicitHeight
            x: contentLayout.hasSavedValue("shortcut", "x")
               ? contentLayout.elementX("shortcut") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("shortcut", "y")
               ? contentLayout.elementY("shortcut") : labelItem.y + labelItem.height + 6
            visible: (screenshotTile.sizeClass === "medium"
                      || screenshotTile.sizeClass === "large")
                     && contentLayout.elementVisible("shortcut")
            z: screenshotTile.selectedElement === "shortcut" ? 20 : 1

            Text {
                id: shortcutText
                text: "WIN + SHIFT + S"
                color: themeManager.secondaryTextColor
                font.pixelSize: 9 * screenshotTile.contentScale
                                * contentLayout.elementFontScale("shortcut")
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "shortcut" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: screenshotTile
        canvas: contentCanvas
        tileId: screenshotTile.tileId
        settings: screenshotTile.settings
        contentEditMode: screenshotTile.contentEditMode
        selectedElement: screenshotTile.selectedElement
        contentScale: screenshotTile.contentScale
        elements: [
            { id: "icon", label: "Icon", scale: 1, textScale: 1,
              visible: true, hasText: false, globalGrowth: "sqrt" },
            { id: "label", label: "Label", scale: 1, textScale: 1,
              visible: true, hasText: true },
            { id: "shortcut", label: "Shortcut", scale: 1, textScale: 1,
              visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "icon") return iconItem
            if (elementId === "label") return labelItem
            if (elementId === "shortcut") return shortcutItem
            return null
        }
    }
}
