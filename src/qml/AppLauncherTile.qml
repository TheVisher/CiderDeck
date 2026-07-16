import QtQuick

CardButton {
    id: appTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1

    readonly property string desktopFile: settings.desktopFile || ""
    readonly property string command: settings.command || ""
    readonly property string iconOverride: settings.iconOverride || ""
    readonly property string targetMonitor: settings.targetMonitor || ""
    readonly property bool raiseExisting: settings.raiseExisting || false
    readonly property string wmClass: desktopFile ? appLaunchManager.wmClassForDesktop(desktopFile) : ""
    readonly property string iconSource: iconOverride
        ? "image://appicon/" + iconOverride
        : desktopFile
          ? "image://appicon/" + desktopFile
          : ""
    readonly property string displayLabel: {
        if (label && label !== "app_launcher") return label
        if (desktopFile) return appLaunchManager.appNameForDesktop(desktopFile)
        return ""
    }
    readonly property real iconSize: Math.min(width * 0.46, height * (showLabel ? 0.48 : 0.58), 78)
    property bool isRunning: false

    function updateRunning() {
        isRunning = wmClass !== "" && kwinClient.isAppRunning(wmClass)
    }

    onClicked: appLaunchManager.launch(desktopFile, command, targetMonitor, raiseExisting)
    Component.onCompleted: updateRunning()

    Connections {
        target: kwinClient
        function onWindowsChanged() { appTile.updateRunning() }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 20
        spacing: 8

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: appTile.iconSize
            height: width
            source: appTile.iconSource
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: source !== ""
        }

        Text {
            width: parent.width
            visible: appTile.showLabel && appTile.displayLabel !== ""
            text: appTile.displayLabel
            color: themeManager.textColor
            font.pixelSize: 12 * Math.max(0.9, Math.min(1.2, appTile.contentScale))
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 9
        height: 9
        radius: 4
        color: themeManager.successColor
        border.width: 2
        border.color: themeManager.backgroundColor
        visible: appTile.isRunning
    }
}
