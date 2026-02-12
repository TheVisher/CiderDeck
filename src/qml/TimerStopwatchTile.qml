import QtQuick

Card {
    id: timerTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})

    Connections {
        target: timerService
        function onFinished() {
            toastModel.showWithAction("Timer finished!", "Add 5min", "timer_add_5", 10000)
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        // Time display
        Text {
            text: timerService.displayTime
            color: themeManager.textColor
            font.pixelSize: {
                switch (timerTile.sizeClass) {
                case "tiny":  return Math.min(timerTile.width, timerTile.height) * 0.3
                case "small": return 28
                default:      return 36
                }
            }
            font.weight: Font.DemiBold
            font.family: "monospace"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Controls (small+)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            visible: timerTile.sizeClass !== "tiny"

            // Start/Pause
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: timerService.state === "running" ? themeManager.errorColor : themeManager.successColor

                Text {
                    anchors.centerIn: parent
                    text: timerService.state === "running" ? "\u23F8" : "\u25B6"
                    color: "white"
                    font.pixelSize: 16
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

                Text {
                    anchors.centerIn: parent
                    text: "\u21BA"
                    color: themeManager.textColor
                    font.pixelSize: 18
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: timerService.reset()
                }
            }
        }

        // Mode toggle (medium+)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: timerTile.sizeClass === "medium" || timerTile.sizeClass === "large"

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
