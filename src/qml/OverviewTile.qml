import QtQuick

CardButton {
    id: overviewTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property string label: parent ? parent.label : ""
    property bool showLabel: parent ? parent.showLabel : true
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Overflow detection
    readonly property real pad: 12
    readonly property real availH: height - pad * 2
    readonly property int iconSize: {
        var dim = Math.min(width, height)
        var base = dim < 160 ? dim * 0.5 : dim < 320 ? dim * 0.4 : dim * 0.35
        return base * contentScale
    }
    readonly property bool labelFits: iconSize + 6 + labelText.implicitHeight <= availH

    onClicked: {
        kwinClient.toggleOverview()
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        LucideIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: overviewTile.iconSize; height: overviewTile.iconSize
            source: "qrc:/icons/lucide/layout-grid.svg"
            color: themeManager.textColor
        }

        Text {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            text: overviewTile.label || "Overview"
            color: themeManager.textColor
            font.pixelSize: 13 * overviewTile.contentScale
            visible: overviewTile.showLabel && overviewTile.labelFits
            elide: Text.ElideRight
            width: overviewTile.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
