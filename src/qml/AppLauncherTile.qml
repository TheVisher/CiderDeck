import QtQuick

CardButton {
    id: appTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true

    readonly property string desktopFile: settings.desktopFile || ""
    readonly property string command: settings.command || ""
    readonly property string iconOverride: settings.iconOverride || ""

    // Resolve icon: override > desktop file icon > desktop file name
    readonly property string iconSource: {
        if (iconOverride) return "image://appicon/" + iconOverride
        if (desktopFile) return "image://appicon/" + desktopFile
        return ""
    }

    onClicked: {
        appLaunchManager.launch(desktopFile, command)
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
                switch (appTile.sizeClass) {
                case "tiny":  return Math.min(appTile.width, appTile.height) * 0.5
                case "small": return Math.min(appTile.width, appTile.height) * 0.4
                default:      return Math.min(appTile.width, appTile.height) * 0.35
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: appTile.label
            color: themeManager.textColor
            font.pixelSize: 13
            visible: appTile.showLabel && appTile.sizeClass !== "tiny" && appTile.label !== ""
            elide: Text.ElideRight
            width: appTile.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
