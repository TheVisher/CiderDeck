import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: tileSettings
    clip: true
    contentHeight: settingsColumn.height
    flickableDirection: Flickable.VerticalFlick

    property string tileId: ""
    property var tileData: tileId ? tileGridModel.getTileById(tileId) : ({})
    property string tileType: tileData.type || ""
    property var settings: tileData.settings || ({})

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    function saveSetting(key, value) {
        var changes = {}
        var newSettings = Object.assign({}, settings)
        newSettings[key] = value
        changes["settings"] = newSettings
        deckConfig.updateTile(tileId, changes)
    }

    function saveProperty(key, value) {
        var changes = {}
        changes[key] = value
        deckConfig.updateTile(tileId, changes)
    }

    ColumnLayout {
        id: settingsColumn
        width: parent.width
        spacing: 14

        // Tile type header
        Text {
            text: tileSettings.tileType.replace("_", " ").replace(/\b\w/g, function(c) { return c.toUpperCase() })
            color: themeManager.accentColor
            font.pixelSize: 15
            font.bold: true
        }

        // --- Common settings ---
        SettingsRow {
            label: "Label"
            TextField {
                text: tileSettings.tileData.label || ""
                placeholderText: "Tile label"
                onEditingFinished: tileSettings.saveProperty("label", text)
                implicitWidth: 180
                color: themeManager.textColor
                background: Rectangle {
                    implicitHeight: 28; radius: 6
                    color: "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }
        }

        SettingsRow {
            label: "Show label"
            Switch {
                checked: tileSettings.tileData.showLabel !== false
                onToggled: tileSettings.saveProperty("showLabel", checked)
            }
        }

        SettingsRow {
            label: "Tile opacity"
            RowLayout {
                spacing: 8
                Slider {
                    from: -0.05; to: 1; stepSize: 0.05
                    value: tileSettings.tileData.opacity !== undefined ? tileSettings.tileData.opacity : -1
                    onMoved: tileSettings.saveProperty("opacity", value < 0 ? -1 : value)
                    implicitWidth: 140
                }
                Text {
                    text: (tileSettings.tileData.opacity || -1) < 0 ? "Global" : Math.round((tileSettings.tileData.opacity || 0) * 100) + "%"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        SettingsRow {
            label: "Content scale"
            RowLayout {
                spacing: 8
                Slider {
                    from: 0.5; to: 2.0; stepSize: 0.05
                    value: tileSettings.settings.contentScale || 1.0
                    onMoved: tileSettings.saveSetting("contentScale", Math.round(value * 100) / 100)
                    implicitWidth: 140
                }
                Text {
                    text: Math.round((tileSettings.settings.contentScale || 1.0) * 100) + "%"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor }

        // --- Type-specific settings ---

        // Clock / Date
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "clock_date"
            Layout.fillWidth: true

            Text {
                text: "Clock / Date"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Time format"
                RowLayout {
                    spacing: 8
                    Button {
                        text: "12h"; flat: true
                        highlighted: (tileSettings.settings.timeFormat || "12h") === "12h"
                        onClicked: tileSettings.saveSetting("timeFormat", "12h")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 }
                        background: Rectangle {
                            implicitWidth: 44; implicitHeight: 28; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                    Button {
                        text: "24h"; flat: true
                        highlighted: (tileSettings.settings.timeFormat || "12h") === "24h"
                        onClicked: tileSettings.saveSetting("timeFormat", "24h")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 }
                        background: Rectangle {
                            implicitWidth: 44; implicitHeight: 28; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }

            SettingsRow {
                label: "Show seconds"
                Switch {
                    checked: tileSettings.settings.showSeconds || false
                    onToggled: tileSettings.saveSetting("showSeconds", checked)
                }
            }

            SettingsRow {
                label: "Date format"
                ComboBox {
                    model: [
                        "ddd, MMM d",
                        "ddd, MMM d, yyyy",
                        "MMM d, yyyy",
                        "MM/dd/yyyy",
                        "dd/MM/yyyy",
                        "yyyy-MM-dd",
                        "MMMM d, yyyy",
                        "ddd, MMMM d"
                    ]
                    currentIndex: {
                        var fmt = tileSettings.settings.dateFormat || "ddd, MMM d"
                        var items = ["ddd, MMM d", "ddd, MMM d, yyyy", "MMM d, yyyy", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MMMM d, yyyy", "ddd, MMMM d"]
                        var idx = items.indexOf(fmt)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: (index) => {
                        var items = ["ddd, MMM d", "ddd, MMM d, yyyy", "MMM d, yyyy", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MMMM d, yyyy", "ddd, MMMM d"]
                        tileSettings.saveSetting("dateFormat", items[index])
                    }
                    implicitWidth: 180
                }
            }
        }

        // App Launcher
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "app_launcher"
            Layout.fillWidth: true

            Text {
                text: "App Launcher"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            // App picker with search
            SettingsRow {
                label: "Application"
                RowLayout {
                    spacing: 6

                    Text {
                        text: tileSettings.settings.desktopFile || "None selected"
                        color: tileSettings.settings.desktopFile ? themeManager.textColor : themeManager.secondaryTextColor
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "Browse..."
                        onClicked: appPickerPopup.open()
                        contentItem: Text {
                            text: parent.text
                            color: themeManager.textColor
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }
                        background: Rectangle {
                            implicitWidth: 70; implicitHeight: 26; radius: 6
                            color: parent.hovered ? themeManager.overlayColor : "transparent"
                            border.width: 1; border.color: themeManager.borderColor
                        }
                    }
                }
            }

            // App picker popup
            Popup {
                id: appPickerPopup
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: 340
                height: 420
                modal: true
                focus: true

                background: Rectangle {
                    color: themeManager.backgroundColor
                    border.width: 1
                    border.color: themeManager.borderColor
                    radius: 12
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Select Application"
                        color: themeManager.textColor
                        font.pixelSize: 15
                        font.bold: true
                    }

                    TextField {
                        id: appSearchField
                        Layout.fillWidth: true
                        placeholderText: "Search apps..."
                        color: themeManager.textColor
                        onTextChanged: appFilterModel.filterText = text
                        background: Rectangle {
                            implicitHeight: 32; radius: 6
                            color: "transparent"
                            border.width: 1; border.color: themeManager.borderColor
                        }

                        Component.onCompleted: forceActiveFocus()
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: appFilterModel

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 36
                            color: appMouseArea.containsMouse ? themeManager.overlayColor : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    source: appIcon ? "image://appicon/" + appIcon : ""
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                    width: 22; height: 22
                                    visible: source !== ""
                                }

                                Text {
                                    text: appName
                                    color: themeManager.textColor
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: desktopFile
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }
                            }

                            MouseArea {
                                id: appMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    tileSettings.saveSetting("desktopFile", desktopFile)
                                    // Also set the label to the app name if label is empty
                                    if (!tileSettings.tileData.label) {
                                        tileSettings.saveProperty("label", appName)
                                    }
                                    appPickerPopup.close()
                                    appSearchField.text = ""
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }

                onClosed: {
                    appSearchField.text = ""
                    appFilterModel.filterText = ""
                }
            }

            SettingsRow {
                label: "Command"
                TextField {
                    text: tileSettings.settings.command || ""
                    placeholderText: "Override command"
                    onEditingFinished: tileSettings.saveSetting("command", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
                }
            }

            SettingsRow {
                label: "Target monitor"
                ComboBox {
                    model: {
                        var names = ["Any"]
                        var monitors = monitorManager.monitors
                        for (var i = 0; i < monitors.length; i++) names.push(monitors[i].name)
                        return names
                    }
                    currentIndex: {
                        var target = tileSettings.settings.targetMonitor || ""
                        if (target === "") return 0
                        var monitors = monitorManager.monitors
                        for (var i = 0; i < monitors.length; i++) {
                            if (monitors[i].name === target) return i + 1
                        }
                        return 0
                    }
                    onActivated: (index) => {
                        if (index === 0) {
                            tileSettings.saveSetting("targetMonitor", "")
                        } else {
                            var monitors = monitorManager.monitors
                            if (index - 1 < monitors.length)
                                tileSettings.saveSetting("targetMonitor", monitors[index - 1].name)
                        }
                    }
                    implicitWidth: 180
                }
            }

            SettingsRow {
                label: "Raise existing"
                Switch {
                    checked: tileSettings.settings.raiseExisting || false
                    onToggled: tileSettings.saveSetting("raiseExisting", checked)
                }
            }

            SettingsRow {
                label: "Icon override"
                TextField {
                    text: tileSettings.settings.iconOverride || ""
                    placeholderText: "Icon name or path"
                    onEditingFinished: tileSettings.saveSetting("iconOverride", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
                }
            }
        }

        // Command Button
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "command_button"
            Layout.fillWidth: true

            Text {
                text: "Command Button"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Command"
                TextField {
                    text: tileSettings.settings.command || ""
                    placeholderText: "Shell command"
                    onEditingFinished: tileSettings.saveSetting("command", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
                }
            }
        }

        // Weather
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "weather"
            Layout.fillWidth: true

            Text {
                text: "Weather"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Unit"
                RowLayout {
                    spacing: 8
                    Button {
                        text: "F"; flat: true
                        highlighted: (tileSettings.settings.unit || "f") === "f"
                        onClicked: tileSettings.saveSetting("unit", "f")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 }
                        background: Rectangle {
                            implicitWidth: 36; implicitHeight: 28; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                    Button {
                        text: "C"; flat: true
                        highlighted: (tileSettings.settings.unit || "f") === "c"
                        onClicked: tileSettings.saveSetting("unit", "c")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 }
                        background: Rectangle {
                            implicitWidth: 36; implicitHeight: 28; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }
        }

        // Media Player
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "media_player"
            Layout.fillWidth: true

            Text {
                text: "Media Player"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Preferred player"
                TextField {
                    text: tileSettings.settings.preferredPlayer || ""
                    placeholderText: "Auto (most recent)"
                    onEditingFinished: tileSettings.saveSetting("preferredPlayer", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
                }
            }
        }

        // Screenshot
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "screenshot"
            Layout.fillWidth: true

            Text {
                text: "Screenshot"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Default monitor"
                ComboBox {
                    model: {
                        var names = ["Interactive"]
                        var monitors = monitorManager.monitors
                        for (var i = 0; i < monitors.length; i++) names.push(monitors[i].name)
                        return names
                    }
                    currentIndex: {
                        var target = tileSettings.settings.defaultMonitor || ""
                        if (target === "") return 0
                        var monitors = monitorManager.monitors
                        for (var i = 0; i < monitors.length; i++) {
                            if (monitors[i].name === target) return i + 1
                        }
                        return 0
                    }
                    onActivated: (index) => {
                        if (index === 0) {
                            tileSettings.saveSetting("defaultMonitor", "")
                        } else {
                            var monitors = monitorManager.monitors
                            if (index - 1 < monitors.length)
                                tileSettings.saveSetting("defaultMonitor", monitors[index - 1].name)
                        }
                    }
                    implicitWidth: 180
                }
            }
        }

        // Timer
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "timer_stopwatch"
            Layout.fillWidth: true

            Text {
                text: "Timer / Stopwatch"
                color: themeManager.accentColor
                font.pixelSize: 14
                font.bold: true
            }

            SettingsRow {
                label: "Default duration"
                RowLayout {
                    spacing: 8
                    SpinBox {
                        from: 1; to: 120
                        value: Math.round((tileSettings.settings.defaultDuration || 300) / 60)
                        onValueModified: tileSettings.saveSetting("defaultDuration", value * 60)
                        implicitWidth: 100
                    }
                    Text {
                        text: "min"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12
                    }
                }
            }
        }

        // Spacer
        Item { Layout.fillHeight: true }
    }
}
