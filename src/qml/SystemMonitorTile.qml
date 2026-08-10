import QtQuick
import QtQuick.Layouts

Card {
    id: sysmonTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property bool monitoringActive: parent ? parent.monitoringActive : false
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property string monitorMode: settings.monitorMode || "overview"
    readonly property bool showGraph: settings.showGraph !== false
    readonly property bool showDetails: settings.showDetails !== false
    readonly property bool showBar: settings.showBar !== false
    readonly property int metricTransitionDuration: 900

    readonly property color metricColor: {
        switch (monitorMode) {
        case "gpu": return "#76b900"
        case "memory": return "#f2c14e"
        case "storage": return "#50c8d8"
        case "network": return "#62d2a2"
        default: return themeManager.accentColor
        }
    }

    readonly property string metricTitle: {
        switch (monitorMode) {
        case "cpu": return "CPU"
        case "gpu": return "GPU"
        case "memory": return "MEMORY"
        case "storage": return "STORAGE"
        case "network": return "NETWORK"
        default: return "SYSTEM OVERVIEW"
        }
    }

    readonly property string metricSubtitle: {
        switch (monitorMode) {
        case "cpu": return systemMonitor.cpuName
        case "gpu": return systemMonitor.gpuAvailable ? systemMonitor.gpuName : "NVIDIA telemetry unavailable"
        case "memory": return systemMonitor.ramTotal + " installed"
        case "storage": return systemMonitor.primaryDriveName
        case "network": return systemMonitor.networkInterface || "No active interface"
        default: return "Live system status"
        }
    }

    readonly property real metricPercent: {
        switch (monitorMode) {
        case "cpu": return systemMonitor.cpuPercent
        case "gpu": return systemMonitor.gpuPercent
        case "memory": return systemMonitor.ramPercent
        case "storage": return systemMonitor.storagePercent
        default: return 0
        }
    }
    property real displayedMetricPercent: metricPercent

    Behavior on displayedMetricPercent {
        enabled: sysmonTile.monitoringActive

        NumberAnimation {
            duration: sysmonTile.metricTransitionDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property var metricHistory: {
        switch (monitorMode) {
        case "cpu": return systemMonitor.cpuHistory
        case "gpu": return systemMonitor.gpuHistory
        case "memory": return systemMonitor.ramHistory
        case "storage": return systemMonitor.storageHistory
        case "network": return systemMonitor.downloadHistory
        default: return []
        }
    }

    function temperature(value) {
        return value > 0 ? Math.round(value) + "°C" : "--"
    }

    Component.onCompleted: systemMonitor.setConsumerActive(sysmonTile, sysmonTile.monitoringActive)
    onMonitoringActiveChanged: systemMonitor.setConsumerActive(sysmonTile, sysmonTile.monitoringActive)

    ListModel {
        id: overviewMetricModel

        ListElement { metricKey: "cpu"; metricLabel: "CPU" }
        ListElement { metricKey: "gpu"; metricLabel: "GPU" }
        ListElement { metricKey: "memory"; metricLabel: "MEMORY" }
        ListElement { metricKey: "storage"; metricLabel: "STORAGE" }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 14

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 4
                    height: 18
                    radius: 2
                    color: sysmonTile.metricColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: sysmonTile.metricTitle
                        color: themeManager.textColor
                        font.pixelSize: 13 * sysmonTile.contentScale
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: sysmonTile.metricSubtitle
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 11 * sysmonTile.contentScale
                        elide: Text.ElideRight
                        visible: sysmonTile.sizeClass !== "tiny"
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: sysmonTile.monitorMode === "overview" ? overviewContent
                               : sysmonTile.monitorMode === "network" ? networkContent
                               : metricContent
            }
        }
    }

    Component {
        id: metricContent

        ColumnLayout {
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: Math.round(sysmonTile.displayedMetricPercent) + "%"
                    color: themeManager.textColor
                    font.pixelSize: 40 * sysmonTile.contentScale
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 2
                    visible: sysmonTile.showDetails && sysmonTile.sizeClass !== "tiny"

                    Text {
                        text: {
                            switch (sysmonTile.monitorMode) {
                            case "cpu": return sysmonTile.temperature(systemMonitor.cpuTemp)
                            case "gpu": return sysmonTile.temperature(systemMonitor.gpuTemp)
                            case "memory": return systemMonitor.ramUsed + " used"
                            case "storage": return systemMonitor.storageFree + " free"
                            default: return ""
                            }
                        }
                        color: sysmonTile.metricColor
                        font.pixelSize: 16 * sysmonTile.contentScale
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: {
                            switch (sysmonTile.monitorMode) {
                            case "cpu": return systemMonitor.cpuFrequencyGHz.toFixed(2) + " GHz"
                            case "gpu": return systemMonitor.gpuMemoryUsed + " / " + systemMonitor.gpuMemoryTotal
                            case "memory": return systemMonitor.ramUsed + " / " + systemMonitor.ramTotal
                            case "storage": return systemMonitor.storageUsed + " / " + systemMonitor.storageTotal
                            default: return ""
                            }
                        }
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 11 * sysmonTile.contentScale
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 5
                radius: 3
                color: themeManager.borderColor
                visible: sysmonTile.showBar

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, sysmonTile.displayedMetricPercent / 100))
                    height: parent.height
                    radius: parent.radius
                    color: sysmonTile.metricPercent >= 90 ? themeManager.errorColor : sysmonTile.metricColor
                }
            }

            MetricSparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 34
                values: sysmonTile.metricHistory
                maxValue: 100
                lineColor: sysmonTile.metricColor
                presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph && sysmonTile.sizeClass !== "tiny"
                visible: sysmonTile.showGraph && sysmonTile.sizeClass !== "tiny"
            }

            RowLayout {
                Layout.fillWidth: true
                visible: sysmonTile.showDetails && sysmonTile.sizeClass !== "tiny"

                Text {
                    text: {
                        if (sysmonTile.monitorMode === "gpu")
                            return systemMonitor.gpuPowerWatts.toFixed(0) + " W / " + systemMonitor.gpuPowerLimit.toFixed(0) + " W"
                        if (sysmonTile.monitorMode === "memory")
                            return "Swap " + systemMonitor.swapUsed + " / " + systemMonitor.swapTotal
                        if (sysmonTile.monitorMode === "storage")
                            return sysmonTile.temperature(systemMonitor.primaryDriveTemp) + "  " + systemMonitor.primaryDriveName
                        return "60 second history"
                    }
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * sysmonTile.contentScale
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: {
                        if (sysmonTile.monitorMode === "gpu")
                            return "Fan " + Math.round(systemMonitor.gpuFanPercent) + "%"
                        if (sysmonTile.monitorMode === "storage")
                            return sysmonTile.temperature(systemMonitor.secondaryDriveTemp) + "  " + systemMonitor.secondaryDriveName
                        return ""
                    }
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10 * sysmonTile.contentScale
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    Layout.maximumWidth: sysmonTile.width * 0.4
                }
            }
        }
    }

    Component {
        id: networkContent

        ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    Text { text: "DOWNLOAD"; color: themeManager.secondaryTextColor; font.pixelSize: 10 * sysmonTile.contentScale }
                    Text { text: systemMonitor.downloadRate; color: "#62d2a2"; font.pixelSize: 28 * sysmonTile.contentScale; font.weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 0
                    Text { text: "UPLOAD"; color: themeManager.secondaryTextColor; font.pixelSize: 10 * sysmonTile.contentScale; Layout.alignment: Qt.AlignRight }
                    Text { text: systemMonitor.uploadRate; color: "#50c8d8"; font.pixelSize: 28 * sysmonTile.contentScale; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                }
            }

            MetricSparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 40
                values: systemMonitor.downloadHistory
                maxValue: 0
                lineColor: "#62d2a2"
                presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph
                visible: sysmonTile.showGraph
            }

            Text {
                Layout.fillWidth: true
                text: "Live throughput · 60 second history"
                color: themeManager.secondaryTextColor
                font.pixelSize: 10 * sysmonTile.contentScale
                visible: sysmonTile.showDetails
            }
        }
    }

    Component {
        id: overviewContent

        GridLayout {
            id: overviewGrid
            columns: width >= 620 ? 4 : 2
            rowSpacing: 10
            columnSpacing: 16

            Repeater {
                model: overviewMetricModel

                delegate: ColumnLayout {
                    id: overviewMetric

                    required property string metricKey
                    required property string metricLabel
                    readonly property real rawPercent: {
                        switch (metricKey) {
                        case "cpu": return systemMonitor.cpuPercent
                        case "gpu": return systemMonitor.gpuPercent
                        case "memory": return systemMonitor.ramPercent
                        case "storage": return systemMonitor.storagePercent
                        default: return 0
                        }
                    }
                    property real displayedPercent: rawPercent
                    readonly property string metricDetail: {
                        switch (metricKey) {
                        case "cpu": return sysmonTile.temperature(systemMonitor.cpuTemp)
                        case "gpu": return sysmonTile.temperature(systemMonitor.gpuTemp)
                        case "memory": return systemMonitor.ramUsed
                        case "storage": return systemMonitor.storageFree + " free"
                        default: return ""
                        }
                    }
                    readonly property var metricHistory: {
                        switch (metricKey) {
                        case "cpu": return systemMonitor.cpuHistory
                        case "gpu": return systemMonitor.gpuHistory
                        case "memory": return systemMonitor.ramHistory
                        case "storage": return systemMonitor.storageHistory
                        default: return []
                        }
                    }
                    readonly property color metricColor: {
                        switch (metricKey) {
                        case "cpu": return themeManager.accentColor
                        case "gpu": return "#76b900"
                        case "memory": return "#f2c14e"
                        case "storage": return "#50c8d8"
                        default: return themeManager.accentColor
                        }
                    }

                    Behavior on displayedPercent {
                        enabled: sysmonTile.monitoringActive

                        NumberAnimation {
                            duration: sysmonTile.metricTransitionDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Text {
                        text: metricLabel
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 10 * sysmonTile.contentScale
                    }
                    Text {
                        text: Math.round(displayedPercent) + "%"
                        color: metricColor
                        font.pixelSize: 30 * sysmonTile.contentScale
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: metricDetail
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 11 * sysmonTile.contentScale
                        visible: sysmonTile.showDetails
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: themeManager.borderColor
                        visible: sysmonTile.showBar

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, displayedPercent / 100))
                            height: parent.height
                            radius: parent.radius
                            color: metricColor
                        }
                    }

                    MetricSparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 36
                        values: metricHistory
                        maxValue: 100
                        lineColor: metricColor
                        presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph
                        visible: sysmonTile.showGraph
                    }
                }
            }
        }
    }
}
