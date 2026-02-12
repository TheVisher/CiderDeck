import QtQuick

CardButton {
    id: cmdTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true

    readonly property string command: settings.command || ""

    // Flash feedback
    property color flashColor: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: cmdTile.flashColor
        opacity: 0.3

        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }

    onClicked: {
        if (command === "") return
        commandRunner.run(command)
    }

    Connections {
        target: commandRunner
        function onFinished(exitCode, stdout_, stderr_) {
            if (exitCode === 0) {
                cmdTile.flashColor = themeManager.successColor
            } else {
                cmdTile.flashColor = themeManager.errorColor
            }
            flashTimer.restart()
        }
    }

    Timer {
        id: flashTimer
        interval: 1200
        onTriggered: cmdTile.flashColor = "transparent"
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "image://appicon/utilities-terminal"
            sourceSize.width: iconSize
            sourceSize.height: iconSize
            width: iconSize
            height: iconSize
            smooth: true

            readonly property int iconSize: {
                switch (cmdTile.sizeClass) {
                case "tiny":  return Math.min(cmdTile.width, cmdTile.height) * 0.45
                case "small": return Math.min(cmdTile.width, cmdTile.height) * 0.35
                default:      return Math.min(cmdTile.width, cmdTile.height) * 0.3
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cmdTile.label || "Command"
            color: themeManager.textColor
            font.pixelSize: 13
            visible: cmdTile.showLabel && cmdTile.sizeClass !== "tiny"
            elide: Text.ElideRight
            width: cmdTile.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
