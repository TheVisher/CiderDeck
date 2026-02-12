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

        Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor }

        // --- Type-specific settings ---

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

            SettingsRow {
                label: "Desktop file"
                TextField {
                    text: tileSettings.settings.desktopFile || ""
                    placeholderText: "e.g. firefox.desktop"
                    onEditingFinished: tileSettings.saveSetting("desktopFile", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
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
