import QtQuick

Card {
    id: weatherTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    Component.onCompleted: {
        if (settings.locations && settings.locations.length > 0) {
            weatherService.setLocations(settings.locations)
        }
        if (settings.unit) {
            weatherService.setUnit(settings.unit)
        }
        weatherService.refresh()
    }

    // Tiny: temperature only
    Text {
        anchors.centerIn: parent
        text: weatherService.temperature || "--"
        color: themeManager.textColor
        font.pixelSize: Math.min(parent.width, parent.height) * 0.3 * weatherTile.contentScale
        font.weight: Font.DemiBold
        visible: weatherTile.sizeClass === "tiny"
    }

    // Small: temp + icon
    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: weatherTile.sizeClass === "small"

        Image {
            source: weatherService.icon ? "image://appicon/" + weatherService.icon : ""
            width: 32 * weatherTile.contentScale
            height: 32 * weatherTile.contentScale
            sourceSize: Qt.size(32, 32)
            visible: source !== ""
        }

        Text {
            text: weatherService.temperature || "--"
            color: themeManager.textColor
            font.pixelSize: 22 * weatherTile.contentScale
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Medium+: full weather info
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4
        visible: weatherTile.sizeClass === "medium" || weatherTile.sizeClass === "large"

        Row {
            spacing: 10
            Image {
                source: weatherService.icon ? "image://appicon/" + weatherService.icon : ""
                width: 40 * weatherTile.contentScale
                height: 40 * weatherTile.contentScale
                sourceSize: Qt.size(40, 40)
                visible: source !== ""
            }
            Column {
                Text {
                    text: weatherService.temperature || "--"
                    color: themeManager.textColor
                    font.pixelSize: 24 * weatherTile.contentScale
                    font.weight: Font.DemiBold
                }
                Text {
                    text: weatherService.condition || ""
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12 * weatherTile.contentScale
                }
            }
        }

        Row {
            spacing: 16
            visible: weatherTile.sizeClass === "large"

            Text {
                text: "Wind: " + (weatherService.windSpeed || "--")
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * weatherTile.contentScale
            }
            Text {
                text: "Humidity: " + (weatherService.humidity || "--")
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * weatherTile.contentScale
            }
        }

        Text {
            text: weatherService.location || ""
            color: themeManager.secondaryTextColor
            font.pixelSize: 10 * weatherTile.contentScale
            visible: text !== ""
        }
    }

    // Swipe for multi-location
    MouseArea {
        anchors.fill: parent
        z: -1
        property real startX: 0
        onPressed: (mouse) => { startX = mouse.x }
        onReleased: (mouse) => {
            let dx = mouse.x - startX
            if (Math.abs(dx) > 50) {
                if (dx < 0) weatherService.nextLocation()
                else weatherService.previousLocation()
            }
        }
    }
}
