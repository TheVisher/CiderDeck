import QtQuick

CardButton {
    id: appTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property string desktopFile: settings.desktopFile || ""
    readonly property string command: settings.command || ""
    readonly property string iconOverride: settings.iconOverride || ""
    readonly property string targetMonitor: settings.targetMonitor || ""
    readonly property bool raiseExisting: settings.raiseExisting || false

    // Resolve WM class for running indicator
    readonly property string wmClass: desktopFile ? appLaunchManager.wmClassForDesktop(desktopFile) : ""
    property bool isRunning: false

    // Resolve icon: override > desktop file icon > desktop file name
    readonly property string iconSource: {
        if (iconOverride) return "image://appicon/" + iconOverride
        if (desktopFile) return "image://appicon/" + desktopFile
        return ""
    }

    function updateRunning() {
        isRunning = wmClass !== "" && kwinClient.isAppRunning(wmClass)
    }

    onClicked: {
        appLaunchManager.launch(desktopFile, command, targetMonitor, raiseExisting)
    }

    Component.onCompleted: updateRunning()

    // Re-evaluate isRunning when window list changes
    Connections {
        target: kwinClient
        function onWindowsChanged() {
            appTile.updateRunning()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Image {
            id: appIcon
            anchors.horizontalCenter: parent.horizontalCenter
            source: appTile.iconSource
            sourceSize.width: iconSize
            sourceSize.height: iconSize
            width: iconSize
            height: iconSize
            smooth: true
            visible: source !== ""

            readonly property int iconSize: {
                var base
                switch (appTile.sizeClass) {
                case "tiny":  base = Math.min(appTile.width, appTile.height) * 0.5; break
                case "small": base = Math.min(appTile.width, appTile.height) * 0.4; break
                default:      base = Math.min(appTile.width, appTile.height) * 0.35; break
                }
                return base * appTile.contentScale
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: appTile.label
            color: themeManager.textColor
            font.pixelSize: 13 * appTile.contentScale
            visible: appTile.showLabel && appTile.sizeClass !== "tiny" && appTile.label !== ""
            elide: Text.ElideRight
            width: appTile.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Running indicator dot
    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: themeManager.accentColor
        visible: appTile.isRunning && appTile.sizeClass !== "tiny"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
    }
}
