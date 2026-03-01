import QtQuick

Card {
    id: timerTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Toggles
    readonly property bool wantControls: settings.showControls !== false
    readonly property bool wantModeToggle: settings.showModeToggle !== false

    // Overflow detection
    readonly property real pad: 12
    readonly property real availH: height - pad * 2
    readonly property real sp: 8

    readonly property real timeH: 36 * contentScale
    readonly property real controlsH: 36
    readonly property real modeH: 24

    readonly property real h0: timeH
    readonly property real h1: h0 + sp + controlsH
    readonly property real h2: h1 + sp + modeH

    readonly property bool controlsFit: h1 <= availH
    readonly property bool modeFits: h2 <= availH

    Connections {
        target: timerService
        function onFinished() {
            toastModel.showWithAction("Timer finished!", "Add 5min", "timer_add_5", 10000)
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: timerTile.sp

        // Time display (always shown)
        Text {
            text: timerService.displayTime
            color: themeManager.textColor
            font.pixelSize: timerTile.timeH
            font.weight: Font.DemiBold
            font.family: "monospace"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Controls (overflow-based)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            visible: timerTile.wantControls && timerTile.controlsFit

            // Start/Pause
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: timerService.state === "running" ? themeManager.errorColor : themeManager.successColor

                LucideIcon {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: timerService.state === "running"
                            ? "qrc:/icons/lucide/pause.svg"
                            : "qrc:/icons/lucide/play.svg"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (timerService.state === "running") {
                            timerService.pause()
                        } else {
                            timerService.start()
                        }
                    }
                }
            }

            // Reset
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: themeManager.overlayColor

                LucideIcon {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: "qrc:/icons/lucide/rotate-ccw.svg"
                    color: themeManager.textColor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: timerService.reset()
                }
            }
        }

        // Mode toggle (overflow-based)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: timerTile.wantModeToggle && timerTile.modeFits

            Rectangle {
                width: timerLabel.width + 16
                height: 24
                radius: 12
                color: timerService.mode === "timer" ? themeManager.accentColor : themeManager.overlayColor

                Text {
                    id: timerLabel
                    anchors.centerIn: parent
                    text: "Timer"
                    color: timerService.mode === "timer" ? "white" : themeManager.textColor
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: timerService.mode = "timer"
                }
            }

            Rectangle {
                width: swLabel.width + 16
                height: 24
                radius: 12
                color: timerService.mode === "stopwatch" ? themeManager.accentColor : themeManager.overlayColor

                Text {
                    id: swLabel
                    anchors.centerIn: parent
                    text: "Stopwatch"
                    color: timerService.mode === "stopwatch" ? "white" : themeManager.textColor
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: timerService.mode = "stopwatch"
                }
            }
        }
    }
}
