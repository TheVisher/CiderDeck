import QtQuick

Card {
    id: timerTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property bool wantControls: settings.showControls !== false
    readonly property bool wantModeToggle: settings.showModeToggle !== false
    readonly property int defaultDuration: settings.defaultDuration || 300
    readonly property real pad: 12

    Component.onCompleted: timerService.setDuration(defaultDuration)
    onDefaultDurationChanged: timerService.setDuration(defaultDuration)

    Connections {
        target: timerService
        function onFinished() {
            toastModel.showWithAction("Timer finished!", "Add 5min", "timer_add_5", 10000)
        }
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: timerTile.pad

        Item {
            id: timeItem
            width: timeText.implicitWidth
            height: timeText.implicitHeight
            x: contentLayout.hasSavedValue("time", "x")
               ? contentLayout.elementX("time") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("time", "y")
               ? contentLayout.elementY("time")
               : Math.max(0, (contentCanvas.height - defaultStackHeight) / 2)
            visible: contentLayout.elementVisible("time")
            z: timerTile.selectedElement === "time" ? 20 : 1

            Text {
                id: timeText
                text: timerService.displayTime
                color: themeManager.textColor
                font.pixelSize: 36 * timerTile.contentScale
                                * contentLayout.elementFontScale("time")
                font.weight: Font.DemiBold
                font.family: "monospace"
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "time" }
        }

        Item {
            id: controlsItem
            readonly property real unit: 36 * timerTile.contentScale
                                         * contentLayout.elementScale("controls")
            width: controlsRow.implicitWidth
            height: controlsRow.implicitHeight
            x: contentLayout.hasSavedValue("controls", "x")
               ? contentLayout.elementX("controls") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("controls", "y")
               ? contentLayout.elementY("controls") : timeItem.y + timeItem.height + 8 * timerTile.contentScale
            visible: timerTile.wantControls && contentLayout.elementVisible("controls")
            z: timerTile.selectedElement === "controls" ? 20 : 1

            Row {
                id: controlsRow
                spacing: 12 * timerTile.contentScale * contentLayout.elementScale("controls")

                Rectangle {
                    width: controlsItem.unit; height: width; radius: width / 2
                    color: timerService.state === "running" ? themeManager.errorColor : themeManager.successColor
                    LucideIcon {
                        anchors.centerIn: parent
                        width: parent.width / 2; height: width
                        source: timerService.state === "running"
                                ? "qrc:/icons/lucide/pause.svg" : "qrc:/icons/lucide/play.svg"
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !timerTile.contentEditMode
                        onClicked: timerService.state === "running" ? timerService.pause() : timerService.start()
                    }
                }
                Rectangle {
                    width: controlsItem.unit; height: width; radius: width / 2
                    color: themeManager.overlayColor
                    LucideIcon {
                        anchors.centerIn: parent
                        width: parent.width / 2; height: width
                        source: "qrc:/icons/lucide/rotate-ccw.svg"
                        color: themeManager.textColor
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !timerTile.contentEditMode
                        onClicked: timerService.reset()
                    }
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "controls" }
        }

        Item {
            id: modeItem
            readonly property real modeScale: contentLayout.elementScale("mode")
            width: modeRow.implicitWidth
            height: modeRow.implicitHeight
            x: contentLayout.hasSavedValue("mode", "x")
               ? contentLayout.elementX("mode") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("mode", "y")
               ? contentLayout.elementY("mode") : controlsItem.y + controlsItem.height + 8 * timerTile.contentScale
            visible: timerTile.wantModeToggle && contentLayout.elementVisible("mode")
            z: timerTile.selectedElement === "mode" ? 20 : 1

            Row {
                id: modeRow
                spacing: 8 * timerTile.contentScale * modeItem.modeScale
                Repeater {
                    model: ["timer", "stopwatch"]
                    Rectangle {
                        required property string modelData
                        readonly property bool active: timerService.mode === modelData
                        width: modeLabel.implicitWidth + 16 * timerTile.contentScale * modeItem.modeScale
                        height: 24 * timerTile.contentScale * modeItem.modeScale
                        radius: height / 2
                        color: active ? themeManager.accentColor : themeManager.overlayColor
                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: modelData === "timer" ? "Timer" : "Stopwatch"
                            color: parent.active ? "white" : themeManager.textColor
                            font.pixelSize: 11 * timerTile.contentScale
                                            * contentLayout.elementFontScale("mode")
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !timerTile.contentEditMode
                            onClicked: timerService.mode = parent.modelData
                        }
                    }
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "mode" }
        }

        readonly property real defaultStackHeight: timeItem.height
                                                   + (controlsItem.visible ? controlsItem.height + 8 * timerTile.contentScale : 0)
                                                   + (modeItem.visible ? modeItem.height + 8 * timerTile.contentScale : 0)
    }

    ContentLayoutController {
        id: contentLayout
        tile: timerTile; canvas: contentCanvas; tileId: timerTile.tileId
        settings: timerTile.settings; contentEditMode: timerTile.contentEditMode
        selectedElement: timerTile.selectedElement; contentScale: timerTile.contentScale
        elements: [
            { id: "time", label: "Time", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "controls", label: "Controls", scale: 1, textScale: 1, visible: true, hasText: false },
            { id: "mode", label: "Mode buttons", scale: 1, textScale: 1, visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "time") return timeItem
            if (elementId === "controls") return controlsItem
            if (elementId === "mode") return modeItem
            return null
        }
    }
}
