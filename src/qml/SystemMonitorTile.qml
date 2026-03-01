import QtQuick

Card {
    id: sysmonTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Toggles
    readonly property bool wantCpuBar: settings.showCpuBar !== false
    readonly property bool wantRamBar: settings.showRamBar !== false
    readonly property bool wantRamDetail: settings.showRamDetail !== false

    // Overflow detection
    readonly property real pad: 12
    readonly property real availH: height - pad * 2
    readonly property real sp: 8

    // Cumulative heights
    readonly property real cpuLabelH: 13 * contentScale
    readonly property real cpuValueH: 24 * contentScale
    readonly property real barH: 4
    readonly property real cpuBlockH: cpuLabelH + 2 + cpuValueH + (wantCpuBar ? 2 + barH : 0)
    readonly property real ramBlockH: cpuLabelH + 2 + cpuValueH + (wantRamBar ? 2 + barH : 0)
    readonly property real ramDetailH: 12 * contentScale

    readonly property real h0: cpuBlockH
    readonly property real h1: h0 + sp + ramBlockH
    readonly property real h2: h1 + 2 + ramDetailH

    readonly property bool ramFits: h1 <= availH
    readonly property bool ramDetailFits: h2 <= availH

    Column {
        anchors.centerIn: parent
        spacing: sysmonTile.sp

        // CPU
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: "CPU"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * sysmonTile.contentScale
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: systemMonitor.cpuPercent.toFixed(0) + "%"
                color: themeManager.textColor
                font.pixelSize: 24 * sysmonTile.contentScale
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: sysmonTile.width * 0.6
                height: 4
                radius: 2
                color: themeManager.borderColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.wantCpuBar

                Rectangle {
                    width: parent.width * (systemMonitor.cpuPercent / 100)
                    height: parent.height
                    radius: 2
                    color: systemMonitor.cpuPercent > 80 ? themeManager.errorColor : themeManager.accentColor
                }
            }
        }

        // RAM (overflow-based)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            visible: sysmonTile.ramFits

            Text {
                text: "RAM"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * sysmonTile.contentScale
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: systemMonitor.ramPercent.toFixed(0) + "%"
                color: themeManager.textColor
                font.pixelSize: 24 * sysmonTile.contentScale
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: sysmonTile.width * 0.6
                height: 4
                radius: 2
                color: themeManager.borderColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.wantRamBar

                Rectangle {
                    width: parent.width * (systemMonitor.ramPercent / 100)
                    height: parent.height
                    radius: 2
                    color: systemMonitor.ramPercent > 80 ? themeManager.errorColor : themeManager.accentColor
                }
            }

            Text {
                text: systemMonitor.ramUsed + " / " + systemMonitor.ramTotal
                color: themeManager.secondaryTextColor
                font.pixelSize: 12 * sysmonTile.contentScale
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.wantRamDetail && sysmonTile.ramDetailFits
            }
        }
    }
}
