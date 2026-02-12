import QtQuick

Card {
    id: sysmonTile

    property string sizeClass: parent ? parent.sizeClass : "small"

    Column {
        anchors.centerIn: parent
        spacing: 8

        // CPU
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: "CPU"
                color: themeManager.secondaryTextColor
                font.pixelSize: sysmonTile.sizeClass === "tiny" ? 9 : 11
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: systemMonitor.cpuPercent.toFixed(0) + "%"
                color: themeManager.textColor
                font.pixelSize: sysmonTile.sizeClass === "tiny" ? 16 : 22
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Simple bar
            Rectangle {
                width: sysmonTile.width * 0.6
                height: 4
                radius: 2
                color: themeManager.borderColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.sizeClass !== "tiny"

                Rectangle {
                    width: parent.width * (systemMonitor.cpuPercent / 100)
                    height: parent.height
                    radius: 2
                    color: systemMonitor.cpuPercent > 80 ? themeManager.errorColor : themeManager.accentColor
                }
            }
        }

        // RAM
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: "RAM"
                color: themeManager.secondaryTextColor
                font.pixelSize: sysmonTile.sizeClass === "tiny" ? 9 : 11
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: systemMonitor.ramPercent.toFixed(0) + "%"
                color: themeManager.textColor
                font.pixelSize: sysmonTile.sizeClass === "tiny" ? 16 : 22
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: sysmonTile.width * 0.6
                height: 4
                radius: 2
                color: themeManager.borderColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.sizeClass !== "tiny"

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
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sysmonTile.sizeClass === "medium" || sysmonTile.sizeClass === "large"
            }
        }
    }
}
