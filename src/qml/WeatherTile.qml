import QtQuick

Card {
    id: weatherTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    Component.onCompleted: {
        if (settings.location && settings.location !== "") {
            weatherService.setLocations([settings.location])
        } else if (settings.locations && settings.locations.length > 0) {
            weatherService.setLocations(settings.locations)
        }
        if (settings.unit) {
            weatherService.setUnit(settings.unit)
        }
        if (settings.refreshMinutes) {
            weatherService.setRefreshInterval(settings.refreshMinutes)
        }
        weatherService.refresh()
    }

    onSettingsChanged: {
        if (settings.unit) {
            weatherService.setUnit(settings.unit)
        }
        if (settings.refreshMinutes) {
            weatherService.setRefreshInterval(settings.refreshMinutes)
        }
        if (settings.location !== undefined) {
            if (settings.location !== "") {
                weatherService.setLocations([settings.location])
            }
            weatherService.refresh()
        }
    }

    // --- Per-element toggle overrides (default true = show) ---
    readonly property bool wantIcon: settings.showIcon !== false
    readonly property bool wantCondition: settings.showCondition !== false
    readonly property bool wantWind: settings.showWind !== false
    readonly property bool wantLocation: settings.showLocation !== false

    // --- Overflow detection ---
    readonly property real pad: 16
    readonly property real availH: height - pad * 2
    readonly property real availW: width - pad * 2
    readonly property real sp: 4 * contentScale

    // Cumulative heights (always computed, independent of visibility)
    readonly property real h0: mainRow.implicitHeight
    readonly property real h1: h0 + sp + conditionText.implicitHeight
    readonly property real h2: h1 + sp + windRow.implicitHeight
    readonly property real h3: h2 + sp + locationText.implicitHeight

    Column {
        id: weatherContent
        anchors.centerIn: parent
        spacing: weatherTile.sp

        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * weatherTile.contentScale

            LucideIcon {
                width: 32 * weatherTile.contentScale
                height: 32 * weatherTile.contentScale
                source: weatherService.icon ? "qrc:/icons/lucide/" + weatherService.icon + ".svg" : ""
                color: themeManager.textColor
                visible: weatherService.icon !== "" && weatherTile.wantIcon
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: weatherService.temperature || "--"
                color: themeManager.textColor
                font.pixelSize: 24 * weatherTile.contentScale
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            id: conditionText
            anchors.horizontalCenter: parent.horizontalCenter
            text: weatherService.condition || ""
            color: themeManager.secondaryTextColor
            font.pixelSize: 12 * weatherTile.contentScale
            visible: text !== "" && weatherTile.wantCondition && weatherTile.h1 <= weatherTile.availH
        }

        Row {
            id: windRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * weatherTile.contentScale
            visible: weatherTile.wantWind
                     && weatherTile.h2 <= weatherTile.availH
                     && windRow.implicitWidth <= weatherTile.availW

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
            id: locationText
            anchors.horizontalCenter: parent.horizontalCenter
            text: weatherService.location || ""
            color: themeManager.secondaryTextColor
            font.pixelSize: 10 * weatherTile.contentScale
            visible: text !== "" && weatherTile.wantLocation && weatherTile.h3 <= weatherTile.availH
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
