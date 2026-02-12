import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: generalSettings
    clip: true
    contentHeight: settingsColumn.height
    flickableDirection: Flickable.VerticalFlick

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: settingsColumn
        width: parent.width
        spacing: 16

        // --- Appearance ---
        Text {
            text: "Appearance"
            color: themeManager.accentColor
            font.pixelSize: 15
            font.bold: true
        }

        // Theme
        SettingsRow {
            label: "Theme"
            RowLayout {
                spacing: 8
                Button {
                    text: "Dark"
                    flat: true
                    highlighted: deckConfig.theme === "dark"
                    onClicked: deckConfig.theme = "dark"
                    contentItem: Text {
                        text: parent.text
                        color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                        font.pixelSize: 13
                    }
                    background: Rectangle {
                        implicitWidth: 60; implicitHeight: 28; radius: 6
                        color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                        border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                    }
                }
                Button {
                    text: "Light"
                    flat: true
                    highlighted: deckConfig.theme === "light"
                    onClicked: deckConfig.theme = "light"
                    contentItem: Text {
                        text: parent.text
                        color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                        font.pixelSize: 13
                    }
                    background: Rectangle {
                        implicitWidth: 60; implicitHeight: 28; radius: 6
                        color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                        border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                    }
                }
            }
        }

        // Follow system theme
        SettingsRow {
            label: "Follow system theme"
            Switch {
                checked: deckConfig.followSystemTheme
                onToggled: deckConfig.followSystemTheme = checked
            }
        }

        // Backdrop blur
        SettingsRow {
            label: "Backdrop blur"
            Switch {
                checked: deckConfig.globalBlur
                onToggled: deckConfig.globalBlur = checked
            }
        }

        // Blur level
        SettingsRow {
            label: "Blur level"
            visible: deckConfig.globalBlur
            Slider {
                from: 0; to: 1; stepSize: 0.05
                value: deckConfig.globalBlurLevel
                onMoved: deckConfig.globalBlurLevel = value
                implicitWidth: 160
            }
        }

        // Global opacity
        SettingsRow {
            label: "Card opacity"
            RowLayout {
                spacing: 8
                Slider {
                    from: 0.1; to: 1; stepSize: 0.05
                    value: deckConfig.globalOpacity
                    onMoved: deckConfig.globalOpacity = value
                    implicitWidth: 140
                }
                Text {
                    text: Math.round(deckConfig.globalOpacity * 100) + "%"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        // Card radius
        SettingsRow {
            label: "Card radius"
            RowLayout {
                spacing: 8
                Slider {
                    from: 0; to: 30; stepSize: 1
                    value: deckConfig.cardRadius
                    onMoved: deckConfig.cardRadius = value
                    implicitWidth: 140
                }
                Text {
                    text: deckConfig.cardRadius + "px"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        // Show labels
        SettingsRow {
            label: "Show tile labels"
            Switch {
                checked: deckConfig.showLabels
                onToggled: deckConfig.showLabels = checked
            }
        }

        // Icon color mode
        SettingsRow {
            label: "Icon colors"
            RowLayout {
                spacing: 6
                Repeater {
                    model: ["original", "greyscale", "muted"]
                    Button {
                        required property string modelData
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        flat: true
                        highlighted: deckConfig.iconColorMode === modelData
                        onClicked: deckConfig.iconColorMode = modelData
                        contentItem: Text {
                            text: parent.text
                            color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                            font.pixelSize: 12
                        }
                        background: Rectangle {
                            implicitWidth: 70; implicitHeight: 26; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor }

        // --- Grid ---
        Text {
            text: "Grid"
            color: themeManager.accentColor
            font.pixelSize: 15
            font.bold: true
        }

        SettingsRow {
            label: "Gap"
            RowLayout {
                spacing: 8
                Slider {
                    from: 0; to: 16; stepSize: 1
                    value: deckConfig.gridGap
                    onMoved: deckConfig.gridGap = value
                    implicitWidth: 140
                }
                Text {
                    text: deckConfig.gridGap + "px"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        SettingsRow {
            label: "Padding"
            RowLayout {
                spacing: 8
                Slider {
                    from: 0; to: 24; stepSize: 1
                    value: deckConfig.padding
                    onMoved: deckConfig.padding = value
                    implicitWidth: 140
                }
                Text {
                    text: deckConfig.padding + "px"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor }

        // --- Display ---
        Text {
            text: "Display"
            color: themeManager.accentColor
            font.pixelSize: 15
            font.bold: true
        }

        SettingsRow {
            label: "Target display"
            ComboBox {
                id: displayCombo
                model: {
                    var names = ["Auto (2560x720)"]
                    var monitors = monitorManager.monitors
                    for (var i = 0; i < monitors.length; i++) {
                        names.push(monitors[i].name)
                    }
                    return names
                }
                currentIndex: {
                    if (deckConfig.targetDisplay === "") return 0
                    var monitors = monitorManager.monitors
                    for (var i = 0; i < monitors.length; i++) {
                        if (monitors[i].name === deckConfig.targetDisplay) return i + 1
                    }
                    return 0
                }
                onActivated: (index) => {
                    if (index === 0) {
                        deckConfig.targetDisplay = ""
                    } else {
                        var monitors = monitorManager.monitors
                        if (index - 1 < monitors.length) {
                            deckConfig.targetDisplay = monitors[index - 1].name
                        }
                    }
                }
                implicitWidth: 180
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor }

        // --- Config ---
        Text {
            text: "Configuration"
            color: themeManager.accentColor
            font.pixelSize: 15
            font.bold: true
        }

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Button {
                text: "Export Config"
                onClicked: {
                    var path = deckConfig.configPath().replace("config.json", "config-export.json")
                    deckConfig.exportConfig(path)
                    toastModel.show("Config exported to " + path, 4000)
                }
                contentItem: Text {
                    text: parent.text
                    color: themeManager.textColor
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    implicitWidth: 120; implicitHeight: 32; radius: 8
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }

            Button {
                text: "Import Config"
                onClicked: {
                    var path = deckConfig.configPath().replace("config.json", "config-export.json")
                    if (deckConfig.importConfig(path)) {
                        toastModel.show("Config imported", 3000)
                    } else {
                        toastModel.show("Import failed", 3000)
                    }
                }
                contentItem: Text {
                    text: parent.text
                    color: themeManager.textColor
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    implicitWidth: 120; implicitHeight: 32; radius: 8
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }
        }

        // Spacer
        Item { Layout.fillHeight: true }
    }
}
