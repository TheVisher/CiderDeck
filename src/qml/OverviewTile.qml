import QtQuick

CardButton {
    id: overviewTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property real pad: 12
    readonly property real availH: height - pad * 2
    readonly property real baseIconSize: {
        var dim = Math.min(width, height)
        var base = dim < 160 ? dim * 0.5 : dim < 320 ? dim * 0.4 : dim * 0.35
        var labelRoom = showLabel && contentLayout.elementVisible("label")
                      ? labelText.implicitHeight + 6 : 0
        return Math.max(12, Math.min(base * contentScale,
                                     width - pad * 2, availH - labelRoom))
    }

    pressAnimationEnabled: !contentEditMode
    onClicked: {
        if (!contentEditMode) kwinClient.toggleOverview()
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: overviewTile.pad

        Item {
            id: iconItem
            width: overviewTile.baseIconSize * contentLayout.elementScale("icon")
            height: width
            x: contentLayout.hasSavedValue("icon", "x")
               ? contentLayout.elementX("icon") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("icon", "y")
               ? contentLayout.elementY("icon")
               : (contentCanvas.height - height - (labelItem.visible ? labelItem.height + 6 : 0)) / 2
            visible: contentLayout.elementVisible("icon")
            z: overviewTile.selectedElement === "icon" ? 20 : 1

            LucideIcon {
                anchors.fill: parent
                source: "qrc:/icons/lucide/layout-grid.svg"
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
            visible: overviewTile.showLabel && contentLayout.elementVisible("label")
            z: overviewTile.selectedElement === "label" ? 20 : 1

            Text {
                id: labelText
                width: parent.width
                text: overviewTile.label || "Overview"
                color: themeManager.textColor
                font.pixelSize: 13 * overviewTile.contentScale
                                * contentLayout.elementFontScale("label")
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "label" }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: overviewTile
        canvas: contentCanvas
        tileId: overviewTile.tileId
        settings: overviewTile.settings
        contentEditMode: overviewTile.contentEditMode
        selectedElement: overviewTile.selectedElement
        contentScale: overviewTile.contentScale
        elements: [
            { id: "icon", label: "Icon", scale: 1, textScale: 1,
              visible: true, hasText: false, globalGrowth: "sqrt" },
            { id: "label", label: "Label", scale: 1, textScale: 1,
              visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "icon") return iconItem
            if (elementId === "label") return labelItem
            return null
        }
    }
}
