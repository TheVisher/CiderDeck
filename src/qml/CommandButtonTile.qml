import QtQuick

CardButton {
    id: cmdTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property string command: settings.command || ""
    readonly property real baseIconSize: {
        var base
        switch (sizeClass) {
        case "tiny":  base = Math.min(width, height) * 0.45; break
        case "small": base = Math.min(width, height) * 0.35; break
        default:      base = Math.min(width, height) * 0.3; break
        }
        return base * contentScale
    }
    property color flashColor: "transparent"

    pressAnimationEnabled: !contentEditMode

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: cmdTile.flashColor
        opacity: 0.3
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    onClicked: {
        if (!contentEditMode && command !== "") commandRunner.run(command)
    }

    Connections {
        target: commandRunner
        function onFinished(exitCode, stdout_, stderr_) {
            cmdTile.flashColor = exitCode === 0
                               ? themeManager.successColor : themeManager.errorColor
            flashTimer.restart()
        }
    }

    Timer {
        id: flashTimer
        interval: 1200
        onTriggered: cmdTile.flashColor = "transparent"
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 10

        Item {
            id: iconItem
            width: cmdTile.baseIconSize * contentLayout.elementScale("icon")
            height: width
            x: contentLayout.hasSavedValue("icon", "x")
               ? contentLayout.elementX("icon") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("icon", "y")
               ? contentLayout.elementY("icon")
               : (contentCanvas.height - height - (labelItem.visible ? labelItem.height + 4 : 0)) / 2
            visible: contentLayout.elementVisible("icon")
            z: cmdTile.selectedElement === "icon" ? 20 : 1

            Image {
                anchors.fill: parent
                source: "image://appicon/utilities-terminal"
                sourceSize.width: width
                sourceSize.height: height
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
               ? contentLayout.elementY("label") : iconItem.y + iconItem.height + 4
            visible: cmdTile.showLabel && cmdTile.sizeClass !== "tiny"
                     && contentLayout.elementVisible("label")
            z: cmdTile.selectedElement === "label" ? 20 : 1

            Text {
                id: labelText
                width: parent.width
                text: cmdTile.label || "Command"
                color: themeManager.textColor
                font.pixelSize: 13 * cmdTile.contentScale
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
        tile: cmdTile
        canvas: contentCanvas
        tileId: cmdTile.tileId
        settings: cmdTile.settings
        contentEditMode: cmdTile.contentEditMode
        selectedElement: cmdTile.selectedElement
        contentScale: cmdTile.contentScale
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
