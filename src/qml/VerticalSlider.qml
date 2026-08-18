import QtQuick

Item {
    id: slider

    signal valueRequested(real value)
    signal iconClicked()

    property real value: 0
    property string label: ""
    property string detail: ""
    property alias iconSource: controlIcon.source
    property color accentColor: themeManager.accentColor
    property bool muted: false
    property bool available: true
    property real contentScale: 1
    property real sliderThickness: 3
    property real knobSize: 1
    property string knobShape: "pill"
    property color knobColor: "#f5f7fa"
    property color iconColor: effectiveAccent
    property color valueColor: themeManager.textColor
    property bool showIcon: true
    property bool showValue: true
    property Item tileHost: slider
    property string tileId: ""
    property var tileSettings: ({})
    property bool contentEditMode: false
    property string selectedElement: ""

    readonly property real clampedValue: Math.max(0, Math.min(1, value))
    readonly property color effectiveAccent: muted ? themeManager.secondaryTextColor : accentColor
    readonly property real trackWidth: 8 * sliderThickness
    readonly property real knobBase: trackWidth + 12 * knobSize
    readonly property real knobCross: knobShape === "square" ? knobBase * 0.85 : knobBase
    readonly property real knobAlong: knobShape === "circle" ? knobBase
        : knobShape === "square" ? knobBase * 0.85 : Math.max(knobBase * 0.55, 8)
    readonly property real knobRadius: knobShape === "circle" ? knobBase / 2
        : knobShape === "square" ? 3 : knobAlong / 2
    readonly property real gap: 8

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 14

        Item {
            id: headerItem
            width: Math.min(headerText.implicitWidth, contentCanvas.width)
            height: headerText.implicitHeight
            x: contentLayout.hasSavedValue("header", "x")
               ? contentLayout.elementX("header") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("header", "y") ? contentLayout.elementY("header") : 0
            visible: contentLayout.elementVisible("header")
            z: slider.selectedElement === "header" ? 20 : 1
            Text {
                id: headerText
                width: parent.width; text: slider.label.toUpperCase()
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * slider.contentScale * contentLayout.elementFontScale("header")
                font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight; renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "header" }
        }

        Item {
            id: iconItem
            width: 46 * slider.contentScale * contentLayout.elementScale("icon")
            height: slider.showIcon ? width : 0
            x: contentLayout.hasSavedValue("icon", "x")
               ? contentLayout.elementX("icon") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("icon", "y")
               ? contentLayout.elementY("icon") : headerItem.y + headerItem.height + slider.gap
            visible: slider.showIcon && contentLayout.elementVisible("icon")
            z: slider.selectedElement === "icon" ? 20 : 1
            Rectangle {
                id: iconButton
                anchors.fill: parent; radius: 8
                color: iconArea.pressed ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.065)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
                LucideIcon {
                    id: controlIcon
                    anchors.centerIn: parent; width: parent.width * 0.46; height: width
                    color: slider.muted ? themeManager.secondaryTextColor : slider.iconColor
                }
                MouseArea {
                    id: iconArea; anchors.fill: parent
                    enabled: slider.available && !slider.contentEditMode
                    onClicked: slider.iconClicked()
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "icon" }
        }

        Item {
            id: railItem
            readonly property real railScale: contentLayout.elementScale("rail")
            // The rail's item-size control changes length only. Thickness and
            // knob size already have their own tile settings.
            width: Math.max(slider.trackWidth, slider.knobCross)
            height: contentCanvas.defaultRailHeight * railScale
            x: contentLayout.hasSavedValue("rail", "x")
               ? contentLayout.elementX("rail") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("rail", "y")
               ? contentLayout.elementY("rail") : iconItem.y + iconItem.height + slider.gap
            visible: contentLayout.elementVisible("rail")
            opacity: slider.available ? 1 : 0.3
            z: slider.selectedElement === "rail" ? 20 : 1
            Rectangle {
                id: track
                anchors.centerIn: parent
                width: slider.trackWidth; height: parent.height
                radius: 8; color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 4
                    height: Math.max(0, (parent.height - 8) * slider.clampedValue)
                    radius: 5; color: slider.effectiveAccent
                    Behavior on height {
                        enabled: !dragArea.pressed
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
                Rectangle {
                    width: slider.knobCross
                    height: slider.knobAlong
                    radius: slider.knobRadius
                    color: slider.knobColor; border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.24)
                    x: (parent.width - width) / 2
                    y: Math.max(0, Math.min(parent.height - height,
                        (parent.height - height) * (1 - slider.clampedValue)))
                }
            }
            MouseArea {
                id: dragArea
                anchors.fill: parent; anchors.leftMargin: -12; anchors.rightMargin: -12
                preventStealing: true; enabled: slider.available && !slider.contentEditMode
                function updateValue(mouse) {
                    var localY = mapToItem(track, mouse.x, mouse.y).y
                    slider.valueRequested(Math.max(0, Math.min(1, 1 - localY / track.height)))
                }
                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse) }
            }
            ContentEditableFrame { host: contentLayout; elementId: "rail" }
        }

        Item {
            id: valueItem
            width: valueText.implicitWidth; height: slider.showValue ? valueText.implicitHeight : 0
            x: contentLayout.hasSavedValue("value", "x")
               ? contentLayout.elementX("value") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("value", "y")
               ? contentLayout.elementY("value") : railItem.y + railItem.height + slider.gap
            visible: slider.showValue && contentLayout.elementVisible("value")
            z: slider.selectedElement === "value" ? 20 : 1
            Text {
                id: valueText; text: Math.round(slider.clampedValue * 100) + "%"
                color: slider.muted ? themeManager.secondaryTextColor : slider.valueColor
                font.pixelSize: 18 * slider.contentScale * contentLayout.elementFontScale("value")
                font.weight: Font.DemiBold; renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "value" }
        }

        Item {
            id: detailItem
            width: Math.min(detailText.implicitWidth, contentCanvas.width)
            height: detailText.implicitHeight
            x: contentLayout.hasSavedValue("detail", "x")
               ? contentLayout.elementX("detail") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("detail", "y")
               ? contentLayout.elementY("detail") : valueItem.y + valueItem.height + slider.gap
            visible: contentLayout.elementVisible("detail")
            z: slider.selectedElement === "detail" ? 20 : 1
            Text {
                id: detailText; width: parent.width
                text: slider.available ? slider.detail : "Unavailable"
                color: slider.available ? themeManager.secondaryTextColor : themeManager.errorColor
                font.pixelSize: 9 * slider.contentScale * contentLayout.elementFontScale("detail")
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "detail" }
        }

        readonly property real defaultRailHeight: Math.max(12, height
            - headerItem.height - iconItem.height - valueItem.height - detailItem.height - slider.gap * 4)
    }

    ContentLayoutController {
        id: contentLayout
        tile: slider.tileHost; canvas: contentCanvas; tileId: slider.tileId
        settings: slider.tileSettings; contentEditMode: slider.contentEditMode
        selectedElement: slider.selectedElement; contentScale: slider.contentScale
        elements: [
            { id: "header", label: "Header", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "icon", label: "Icon", scale: 1, textScale: 1, visible: true, hasText: false, globalGrowth: "sqrt" },
            { id: "rail", label: "Slider", scale: 1, textScale: 1, visible: true, hasText: false, globalGrowth: "none" },
            { id: "value", label: "Value", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "detail", label: "Detail", scale: 1, textScale: 1, visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "header") return headerItem
            if (elementId === "icon") return iconItem
            if (elementId === "rail") return railItem
            if (elementId === "value") return valueItem
            if (elementId === "detail") return detailItem
            return null
        }
    }
}
