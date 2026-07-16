import QtQuick

Card {
    id: weatherTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1
    readonly property real uiScale: Math.max(0.9, Math.min(1.25, contentScale))
    readonly property bool expanded: width >= 460 && height >= 190

    Component.onCompleted: {
        if (settings.location && settings.location !== "") {
            weatherService.setLocations([settings.location])
        } else if (settings.locations && settings.locations.length > 0) {
            weatherService.setLocations(settings.locations)
        }
        if (settings.unit) weatherService.setUnit(settings.unit)
        if (settings.refreshMinutes) weatherService.setRefreshInterval(settings.refreshMinutes)
        weatherService.refresh()
    }

    onSettingsChanged: {
        if (settings.unit) weatherService.setUnit(settings.unit)
        if (settings.refreshMinutes) weatherService.setRefreshInterval(settings.refreshMinutes)
        if (settings.location !== undefined && settings.location !== "") {
            weatherService.setLocations([settings.location])
            weatherService.refresh()
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 20

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 8

            Rectangle {
                width: 5
                height: 18 * weatherTile.uiScale
                radius: 2
                color: "#f6c85f"
            }

            Text {
                text: "CURRENT CONDITIONS"
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * weatherTile.uiScale
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            width: parent.width * 0.42
            text: weatherService.location || ""
            color: themeManager.secondaryTextColor
            font.pixelSize: 11 * weatherTile.uiScale
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }

        Row {
            id: primaryWeather
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 10
            spacing: 18

            LucideIcon {
                width: 80 * weatherTile.uiScale
                height: width
                source: weatherService.icon
                        ? "qrc:/icons/lucide/" + weatherService.icon + ".svg"
                        : "qrc:/icons/lucide/cloud-sun.svg"
                color: "#f6c85f"
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: weatherService.temperature || "--"
                    color: themeManager.textColor
                    font.pixelSize: 48 * weatherTile.uiScale
                    font.weight: Font.DemiBold
                }
                Text {
                    text: weatherService.condition || "Updating"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 15 * weatherTile.uiScale
                    width: 210 * weatherTile.uiScale
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 12
            spacing: 26
            visible: weatherTile.expanded

            Column {
                spacing: 8
                LucideIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 27 * weatherTile.uiScale
                    height: width
                    source: "qrc:/icons/lucide/wind.svg"
                    color: "#76c7f2"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: weatherService.windSpeed || "--"
                    color: themeManager.textColor
                    font.pixelSize: 16 * weatherTile.uiScale
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "WIND"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 9 * weatherTile.uiScale
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                width: 1
                height: 84 * weatherTile.uiScale
                color: Qt.rgba(1, 1, 1, 0.10)
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 8
                LucideIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 27 * weatherTile.uiScale
                    height: width
                    source: "qrc:/icons/lucide/droplets.svg"
                    color: "#5dd6c0"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: weatherService.humidity || "--"
                    color: themeManager.textColor
                    font.pixelSize: 16 * weatherTile.uiScale
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "HUMIDITY"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 9 * weatherTile.uiScale
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        property real startX: 0
        onPressed: (mouse) => startX = mouse.x
        onReleased: (mouse) => {
            var delta = mouse.x - startX
            if (delta < -60) weatherService.nextLocation()
            else if (delta > 60) weatherService.previousLocation()
        }
    }
}
