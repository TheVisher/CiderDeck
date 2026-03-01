import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Flickable {
    id: tileSettings
    clip: true
    contentHeight: settingsColumn.height
    flickableDirection: Flickable.VerticalFlick

    property string tileId: ""
    readonly property real ts: deckConfig.settingsTextScale
    property int _refreshCounter: 0
    property var tileData: {
        _refreshCounter  // force re-evaluation when counter changes
        return tileId ? tileGridModel.getTileById(tileId) : ({})
    }
    property string tileType: tileData.type || ""
    property var settings: tileData.settings || ({})

    // Audio mixer: which group index the app picker is targeting
    property int mixerAppPickerGroupIdx: -1

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    function saveSetting(key, value) {
        var changes = {}
        var newSettings = Object.assign({}, settings)
        newSettings[key] = value
        changes["settings"] = newSettings
        deckConfig.updateTile(tileId, changes)
        _refreshCounter++
    }

    function saveProperty(key, value) {
        var changes = {}
        changes[key] = value
        deckConfig.updateTile(tileId, changes)
        _refreshCounter++
    }

    ColumnLayout {
        id: settingsColumn
        width: parent.width
        spacing: 14

        // Tile type header
        Text {
            text: tileSettings.tileType.replace("_", " ").replace(/\b\w/g, function(c) { return c.toUpperCase() })
            color: themeManager.accentColor
            font.pixelSize: 15 * tileSettings.ts
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
                    font.pixelSize: 12 * tileSettings.ts
                }
            }
        }

        SettingsRow {
            label: "Content scale"
            RowLayout {
                spacing: 8
                Slider {
                    id: contentScaleSlider
                    from: 0.5; to: 5.0; stepSize: 0.05
                    value: tileSettings.settings.contentScale !== undefined && tileSettings.settings.contentScale > 0
                           ? tileSettings.settings.contentScale : deckConfig.globalTextScale
                    onMoved: tileSettings.saveSetting("contentScale", Math.round(value * 100) / 100)
                    implicitWidth: 120
                }
                Text {
                    text: {
                        var hasOverride = tileSettings.settings.contentScale !== undefined && tileSettings.settings.contentScale > 0
                        return Math.round(contentScaleSlider.value * 100) + "%" + (hasOverride ? "" : " (global)")
                    }
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 12 * tileSettings.ts
                }
                Button {
                    text: "Reset"
                    visible: tileSettings.settings.contentScale !== undefined && tileSettings.settings.contentScale > 0
                    flat: true
                    onClicked: tileSettings.saveSetting("contentScale", 0)
                    contentItem: Text {
                        text: parent.text
                        color: themeManager.accentColor
                        font.pixelSize: 11 * tileSettings.ts
                    }
                    background: Rectangle {
                        implicitWidth: 40; implicitHeight: 22; radius: 4
                        color: parent.hovered ? themeManager.overlayColor : "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
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
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Clock style"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "classic", label: "Classic" },
                            { value: "modern", label: "Modern" },
                            { value: "flip", label: "Flip" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.clockStyle || "classic") === modelData.value
                            onClicked: tileSettings.saveSetting("clockStyle", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 56; implicitHeight: 28; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            SettingsRow {
                label: "Time format"
                RowLayout {
                    spacing: 8
                    Button {
                        text: "12h"; flat: true
                        highlighted: (tileSettings.settings.timeFormat || "12h") === "12h"
                        onClicked: tileSettings.saveSetting("timeFormat", "12h")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
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
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
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
                label: "Show date"
                Switch {
                    checked: tileSettings.settings.showDate !== false
                    onToggled: tileSettings.saveSetting("showDate", checked)
                }
            }

            SettingsRow {
                label: "Date position"
                visible: tileSettings.settings.showDate !== false
                ComboBox {
                    model: ["Below", "Above", "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Top Center", "Bottom Center"]
                    property var posValues: ["below", "above", "top-left", "top-right", "bottom-left", "bottom-right", "top-center", "bottom-center"]
                    currentIndex: {
                        var pos = tileSettings.settings.datePosition || "below"
                        var idx = posValues.indexOf(pos)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: (index) => {
                        tileSettings.saveSetting("datePosition", posValues[index])
                    }
                    implicitWidth: 180
                }
            }

            SettingsRow {
                label: "Date format"
                visible: (tileSettings.settings.clockStyle || "classic") !== "modern"
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
                font.pixelSize: 15 * tileSettings.ts
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
                        font.pixelSize: 12 * tileSettings.ts
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "Browse..."
                        onClicked: appPickerPopup.open()
                        contentItem: Text {
                            text: parent.text
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
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
                        font.pixelSize: 15 * tileSettings.ts
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
                                    font.pixelSize: 13 * tileSettings.ts
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: desktopFile
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10 * tileSettings.ts
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

        // Volume
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "volume"
            Layout.fillWidth: true

            Text {
                text: "Volume"
                color: themeManager.accentColor
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Show percent"
                Switch {
                    checked: tileSettings.settings.showPercent !== false
                    onToggled: tileSettings.saveSetting("showPercent", checked)
                }
            }

            SettingsRow {
                label: "Show mute button"
                Switch {
                    checked: tileSettings.settings.showMuteBtn !== false
                    onToggled: tileSettings.saveSetting("showMuteBtn", checked)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Slider"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Track thickness"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: volThicknessSlider
                        from: 0.5; to: 5.0; stepSize: 0.25
                        value: tileSettings.settings.sliderThickness || 1.0
                        onMoved: tileSettings.saveSetting("sliderThickness", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(volThicknessSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob size"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: volKnobSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.knobSize || 1.0
                        onMoved: tileSettings.saveSetting("knobSize", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(volKnobSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob shape"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "pill", label: "Pill" },
                            { value: "circle", label: "Circle" },
                            { value: "square", label: "Square" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.knobShape || "pill") === modelData.value
                            onClicked: tileSettings.saveSetting("knobShape", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Colors"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            // Color picker rows for volume slider
            Repeater {
                model: [
                    { key: "iconColor", label: "Icon" },
                    { key: "barColor", label: "Bar fill" },
                    { key: "knobColor", label: "Knob" },
                    { key: "percentColor", label: "Percent" }
                ]
                ColumnLayout {
                    id: volColorRow
                    required property var modelData
                    property string colorKey: modelData.key
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: volColorRow.modelData.label
                        color: themeManager.textColor
                        font.pixelSize: 13 * tileSettings.ts
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { hex: "", label: "Default" },
                                { hex: "#ffffff", label: "White" },
                                { hex: "#4488ff", label: "Blue" },
                                { hex: "#FFD54F", label: "Yellow" },
                                { hex: "#ff4444", label: "Red" },
                                { hex: "#44dd66", label: "Green" },
                                { hex: "#ff8844", label: "Orange" },
                                { hex: "#cc44ff", label: "Purple" },
                                { hex: "#44dddd", label: "Cyan" },
                                { hex: "#ff66aa", label: "Pink" }
                            ]
                            Rectangle {
                                required property var modelData
                                width: 22; height: 22; radius: 11
                                color: modelData.hex === "" ? themeManager.overlayColor : modelData.hex
                                border.width: (tileSettings.settings[volColorRow.colorKey] || "") === modelData.hex ? 2 : 1
                                border.color: (tileSettings.settings[volColorRow.colorKey] || "") === modelData.hex
                                    ? themeManager.accentColor : themeManager.borderColor
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.hex === "" ? "D" : ""
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10 * tileSettings.ts; font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: tileSettings.saveSetting(volColorRow.colorKey, parent.modelData.hex)
                                }
                            }
                        }

                        TextField {
                            text: tileSettings.settings[volColorRow.colorKey] || ""
                            placeholderText: "#hex"
                            onEditingFinished: tileSettings.saveSetting(volColorRow.colorKey, text)
                            width: 70
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 24; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Audio Devices"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Device label"
                visible: {
                    var devs = tileSettings.settings.volumeDevices
                    return devs && devs.length > 0
                }
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "text", label: "Text" },
                            { value: "icon", label: "Icon" },
                            { value: "both", label: "Both" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.deviceLabelMode || "text") === modelData.value
                            onClicked: tileSettings.saveSetting("deviceLabelMode", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 44; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Text {
                visible: {
                    var devs = tileSettings.settings.volumeDevices
                    return !devs || devs.length === 0
                }
                text: "Default sink (add devices to enable swipe)"
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * tileSettings.ts
                font.italic: true
            }

            // List of configured devices
            Repeater {
                id: volDeviceRepeater
                model: {
                    var devs = tileSettings.settings.volumeDevices
                    if (!devs || devs.length === 0) return []
                    if (typeof devs === "string") {
                        try { return JSON.parse(devs) } catch(e) { return [] }
                    }
                    return devs
                }
                ColumnLayout {
                    id: devEntry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: themeManager.overlayColor
                            Text {
                                anchors.centerIn: parent
                                text: devEntry.modelData.type === "source" ? "M" : devEntry.modelData.type === "sinkInput" ? "A" : devEntry.modelData.type === "sourceOutput" ? "R" : "S"
                                color: themeManager.secondaryTextColor
                                font.pixelSize: 10 * tileSettings.ts; font.bold: true
                            }
                        }

                        Text {
                            text: devEntry.modelData.name || "Unknown"
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                var t = devEntry.modelData.type || "sink"
                                if ((devEntry.modelData.matchBy || "stream") === "app") t += " (app)"
                                return t
                            }
                            color: themeManager.secondaryTextColor
                            font.pixelSize: 10 * tileSettings.ts
                        }

                        Button {
                            text: "X"
                            flat: true
                            onClicked: {
                                var devs = tileSettings.settings.volumeDevices || []
                                if (typeof devs === "string") {
                                    try { devs = JSON.parse(devs) } catch(e) { devs = [] }
                                }
                                // Unmute the device before removing it
                                var removing = devs[devEntry.index]
                                if (removing && audioManager) {
                                    var devType = removing.type || "sink"
                                    var devName = removing.name || ""
                                    if (devName !== "") {
                                        var count = audioManager.deviceCount(devType)
                                        for (var j = 0; j < count; j++) {
                                            if (audioManager.deviceDescription(devType, j) === devName
                                                || audioManager.deviceName(devType, j) === devName) {
                                                if (audioManager.deviceMuted(devType, j)) {
                                                    audioManager.setDeviceMuted(devType, j, false)
                                                }
                                                break
                                            }
                                        }
                                    }
                                }
                                devs = devs.filter(function(_, i) { return i !== devEntry.index })
                                tileSettings.saveSetting("volumeDevices", devs)
                            }
                            contentItem: Text {
                                text: parent.text; color: themeManager.errorColor
                                font.pixelSize: 12 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 24; implicitHeight: 22; radius: 4
                                color: parent.hovered ? themeManager.overlayColor : "transparent"
                            }
                        }
                    }

                    // Icon path for this device
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 26
                        spacing: 4

                        Text {
                            text: "Icon:"
                            color: themeManager.secondaryTextColor
                            font.pixelSize: 11 * tileSettings.ts
                        }

                        TextField {
                            id: iconField
                            text: devEntry.modelData.icon || ""
                            placeholderText: "path to icon"
                            onEditingFinished: devEntry.setIcon(text)
                            Layout.fillWidth: true
                            color: themeManager.textColor
                            font.pixelSize: 11 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 24; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }

                        Button {
                            text: "..."
                            flat: true
                            onClicked: iconFileDialog.open()
                            contentItem: Text {
                                text: parent.text
                                color: themeManager.accentColor
                                font.pixelSize: 12 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 28; implicitHeight: 24; radius: 4
                                color: parent.hovered ? themeManager.overlayColor : "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }

                        // Preview of current icon
                        Image {
                            visible: (devEntry.modelData.icon || "") !== ""
                            source: devEntry.modelData.icon || ""
                            sourceSize.width: 18; sourceSize.height: 18
                            width: 18; height: 18
                        }

                        FileDialog {
                            id: iconFileDialog
                            title: "Select Icon"
                            nameFilters: ["Images (*.svg *.png *.jpg *.jpeg *.ico *.webp)", "All files (*)"]
                            onAccepted: {
                                var path = selectedFile.toString()
                                // Convert file:// URL to local path
                                if (path.startsWith("file://")) path = path.substring(7)
                                devEntry.setIcon(path)
                                iconField.text = path
                            }
                        }
                    }

                    // Match mode toggle (only for sinkInput type)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 26
                        spacing: 4
                        visible: (devEntry.modelData.type || "sink") === "sinkInput" || (devEntry.modelData.type || "sink") === "sourceOutput"

                        Text {
                            text: "Match:"
                            color: themeManager.secondaryTextColor
                            font.pixelSize: 11 * tileSettings.ts
                        }

                        Repeater {
                            model: [
                                { value: "stream", label: "Stream" },
                                { value: "app", label: "App (all streams)" }
                            ]
                            Button {
                                required property var modelData
                                text: modelData.label; flat: true
                                highlighted: (devEntry.modelData.matchBy || "stream") === modelData.value
                                onClicked: devEntry.setMatchBy(modelData.value)
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                                    font.pixelSize: 11 * tileSettings.ts
                                }
                                background: Rectangle {
                                    implicitWidth: 50; implicitHeight: 22; radius: 4
                                    color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                    border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                                }
                            }
                        }
                    }

                    function setIcon(iconPath) {
                        var devs = tileSettings.settings.volumeDevices || []
                        if (typeof devs === "string") {
                            try { devs = JSON.parse(devs) } catch(e) { devs = [] }
                        }
                        var newDevs = []
                        for (var i = 0; i < devs.length; i++) {
                            var d = Object.assign({}, devs[i])
                            if (i === devEntry.index) d.icon = iconPath
                            newDevs.push(d)
                        }
                        tileSettings.saveSetting("volumeDevices", newDevs)
                    }

                    function setMatchBy(mode) {
                        var devs = tileSettings.settings.volumeDevices || []
                        if (typeof devs === "string") {
                            try { devs = JSON.parse(devs) } catch(e) { devs = [] }
                        }
                        var newDevs = []
                        for (var i = 0; i < devs.length; i++) {
                            var d = Object.assign({}, devs[i])
                            if (i === devEntry.index) d.matchBy = mode
                            newDevs.push(d)
                        }
                        tileSettings.saveSetting("volumeDevices", newDevs)
                    }
                }
            }

            Button {
                text: "+ Add Device"
                flat: true
                onClicked: audioDevicePickerPopup.open()
                contentItem: Text {
                    text: parent.text
                    color: themeManager.accentColor
                    font.pixelSize: 12 * tileSettings.ts
                }
                background: Rectangle {
                    implicitWidth: 100; implicitHeight: 28; radius: 6
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }

            // Audio device picker popup
            Popup {
                id: audioDevicePickerPopup
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: 360; height: 420
                modal: true; focus: true

                background: Rectangle {
                    color: themeManager.backgroundColor
                    border.width: 1; border.color: themeManager.borderColor; radius: 12
                }

                property string selectedTab: "sink"

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Text {
                        text: "Add Audio Device"
                        color: themeManager.textColor
                        font.pixelSize: 15 * tileSettings.ts; font.bold: true
                    }

                    // Tab buttons
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: [
                                { value: "sink", label: "Sinks" },
                                { value: "source", label: "Sources" },
                                { value: "sinkInput", label: "Apps" },
                                { value: "sourceOutput", label: "Mic Capture" }
                            ]
                            Button {
                                required property var modelData
                                text: modelData.label; flat: true
                                highlighted: audioDevicePickerPopup.selectedTab === modelData.value
                                onClicked: audioDevicePickerPopup.selectedTab = modelData.value
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                                    font.pixelSize: 13 * tileSettings.ts
                                }
                                background: Rectangle {
                                    implicitWidth: 60; implicitHeight: 28; radius: 6
                                    color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                    border.width: 1
                                    border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                                }
                            }
                        }
                    }

                    // Device list
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: audioManager ? audioManager.deviceCount(audioDevicePickerPopup.selectedTab) : 0

                        delegate: Rectangle {
                            required property int index
                            width: ListView.view.width; height: 44
                            color: audioDevItemArea.containsMouse ? themeManager.overlayColor : "transparent"
                            radius: 6

                            readonly property string devDesc: audioManager ? audioManager.deviceDescription(audioDevicePickerPopup.selectedTab, index) : ""
                            readonly property string devBinary: (audioDevicePickerPopup.selectedTab === "sinkInput" || audioDevicePickerPopup.selectedTab === "sourceOutput") && audioManager
                                ? audioManager.deviceAppBinary(audioDevicePickerPopup.selectedTab, index) : ""

                            ColumnLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                anchors.topMargin: 4; anchors.bottomMargin: 4
                                spacing: 0

                                Text {
                                    text: parent.parent.devDesc
                                    color: themeManager.textColor
                                    font.pixelSize: 13 * tileSettings.ts
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }

                                Text {
                                    visible: parent.parent.devBinary !== ""
                                    text: "binary: " + parent.parent.devBinary
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10 * tileSettings.ts
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: audioDevItemArea
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    var devType = audioDevicePickerPopup.selectedTab
                                    var devName = audioManager.deviceDescription(devType, parent.index)
                                    var devs = tileSettings.settings.volumeDevices || []
                                    if (typeof devs === "string") {
                                        try { devs = JSON.parse(devs) } catch(e) { devs = [] }
                                    }
                                    var newDevs = []
                                    for (var i = 0; i < devs.length; i++) newDevs.push(devs[i])
                                    // For sinkInput/sourceOutput (Apps/Mic tabs), default to app-level matching
                                    var entry = { type: devType, name: devName }
                                    if (devType === "sinkInput" || devType === "sourceOutput") entry.matchBy = "app"
                                    newDevs.push(entry)
                                    tileSettings.saveSetting("volumeDevices", newDevs)
                                    audioDevicePickerPopup.close()
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }

                    // Custom app name entry (for apps with ephemeral streams like Discord)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        TextField {
                            id: customAppField
                            placeholderText: "Type app name (e.g. Discord)"
                            Layout.fillWidth: true
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 30; radius: 6; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                            onAccepted: addCustomAppBtn.addCustomApp()
                        }

                        Button {
                            id: addCustomAppBtn
                            text: "Add"
                            flat: true
                            enabled: customAppField.text.trim() !== ""
                            onClicked: addCustomApp()
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? themeManager.accentColor : themeManager.secondaryTextColor
                                font.pixelSize: 12 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 48; implicitHeight: 30; radius: 6
                                color: parent.hovered && parent.enabled ? themeManager.overlayColor : "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }

                            function addCustomApp() {
                                var appName = customAppField.text.trim()
                                if (appName === "") return
                                var devs = tileSettings.settings.volumeDevices || []
                                if (typeof devs === "string") {
                                    try { devs = JSON.parse(devs) } catch(e) { devs = [] }
                                }
                                var newDevs = []
                                for (var i = 0; i < devs.length; i++) newDevs.push(devs[i])
                                newDevs.push({ type: "sinkInput", name: appName, matchBy: "app" })
                                tileSettings.saveSetting("volumeDevices", newDevs)
                                customAppField.text = ""
                                audioDevicePickerPopup.close()
                            }
                        }
                    }

                    Text {
                        text: "Tip: type app name for apps not in the list (e.g. Discord when not in a call)"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 10 * tileSettings.ts
                        font.italic: true
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // Clipboard
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "clipboard"
            Layout.fillWidth: true

            Text {
                text: "Clipboard"
                color: themeManager.accentColor
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Show header"
                Switch {
                    checked: tileSettings.settings.showHeader !== false
                    onToggled: tileSettings.saveSetting("showHeader", checked)
                }
            }

            SettingsRow {
                label: "Show timestamps"
                Switch {
                    checked: tileSettings.settings.showTimestamps !== false
                    onToggled: tileSettings.saveSetting("showTimestamps", checked)
                }
            }

            SettingsRow {
                label: "Show scrollbar"
                Switch {
                    checked: tileSettings.settings.showScrollbar !== false
                    onToggled: tileSettings.saveSetting("showScrollbar", checked)
                }
            }

            SettingsRow {
                label: "Thumbnail height"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: thumbHeightSlider
                        from: 30; to: 200; stepSize: 10
                        value: tileSettings.settings.thumbnailHeight || 80
                        onMoved: tileSettings.saveSetting("thumbnailHeight", value)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(thumbHeightSlider.value) + "px"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Max entries"
                RowLayout {
                    spacing: 8
                    SpinBox {
                        from: 5; to: 50; stepSize: 5
                        value: tileSettings.settings.maxEntries || 20
                        onValueModified: tileSettings.saveSetting("maxEntries", value)
                        implicitWidth: 110
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
                font.pixelSize: 15 * tileSettings.ts
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
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Location"
                TextField {
                    text: tileSettings.settings.location || ""
                    placeholderText: "Auto-detect"
                    onEditingFinished: tileSettings.saveSetting("location", text)
                    implicitWidth: 180
                    color: themeManager.textColor
                    background: Rectangle {
                        implicitHeight: 28; radius: 6; color: "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                    }
                }
            }

            SettingsRow {
                label: "Refresh"
                RowLayout {
                    spacing: 8
                    SpinBox {
                        from: 5; to: 120; stepSize: 5
                        value: tileSettings.settings.refreshMinutes || 30
                        onValueModified: tileSettings.saveSetting("refreshMinutes", value)
                        implicitWidth: 110
                    }
                    Text {
                        text: "min"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Unit"
                RowLayout {
                    spacing: 8
                    Button {
                        text: "F"; flat: true
                        highlighted: (tileSettings.settings.unit || "f") === "f"
                        onClicked: tileSettings.saveSetting("unit", "f")
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
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
                        contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                        background: Rectangle {
                            implicitWidth: 36; implicitHeight: 28; radius: 6
                            color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                            border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Elements"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Show icon"
                Switch {
                    checked: tileSettings.settings.showIcon !== false
                    onToggled: tileSettings.saveSetting("showIcon", checked)
                }
            }
            SettingsRow {
                label: "Show condition"
                Switch {
                    checked: tileSettings.settings.showCondition !== false
                    onToggled: tileSettings.saveSetting("showCondition", checked)
                }
            }
            SettingsRow {
                label: "Show wind/humidity"
                Switch {
                    checked: tileSettings.settings.showWind !== false
                    onToggled: tileSettings.saveSetting("showWind", checked)
                }
            }
            SettingsRow {
                label: "Show location"
                Switch {
                    checked: tileSettings.settings.showLocation !== false
                    onToggled: tileSettings.saveSetting("showLocation", checked)
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
                font.pixelSize: 15 * tileSettings.ts
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

            SettingsRow {
                label: "Player switcher"
                Switch {
                    checked: tileSettings.settings.showPlayerSwitcher !== false
                    onToggled: tileSettings.saveSetting("showPlayerSwitcher", checked)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Album Art"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Fade mode"
                ComboBox {
                    id: fadeModeCombo
                    model: ["Bottom", "All Edges", "Radial", "None"]
                    property var modeValues: ["bottom", "edges", "radial", "none"]
                    currentIndex: {
                        var mode = tileSettings.settings.artFadeMode || "bottom"
                        var idx = modeValues.indexOf(mode)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: (index) => {
                        tileSettings.saveSetting("artFadeMode", modeValues[index])
                    }
                    implicitWidth: 150
                }
            }

            SettingsRow {
                label: "Art opacity"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: artOpacitySlider
                        from: 0.1; to: 1.0; stepSize: 0.05
                        value: tileSettings.settings.artPeakOpacity !== undefined ? tileSettings.settings.artPeakOpacity : 0.5
                        onMoved: tileSettings.saveSetting("artPeakOpacity", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(artOpacitySlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Fade start"
                visible: (tileSettings.settings.artFadeMode || "bottom") !== "none"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: fadeStartSlider
                        from: 0.0; to: 0.8; stepSize: 0.05
                        value: tileSettings.settings.artFadePosition !== undefined ? tileSettings.settings.artFadePosition : 0.0
                        onMoved: tileSettings.saveSetting("artFadePosition", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(fadeStartSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Info Layout"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Layout"
                ComboBox {
                    id: infoLayoutCombo
                    model: ["Left", "Right", "Top", "Bottom", "Center", "Art Only", "Text Only"]
                    property var layoutValues: ["left", "right", "top", "bottom", "center", "art-only", "text-only"]
                    currentIndex: {
                        var layout = tileSettings.settings.infoLayout || "left"
                        var idx = layoutValues.indexOf(layout)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: (index) => {
                        tileSettings.saveSetting("infoLayout", layoutValues[index])
                    }
                    implicitWidth: 150
                }
            }

            SettingsRow {
                label: "Art size"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: artSizeSlider
                        from: 0; to: 200; stepSize: 4
                        value: tileSettings.settings.artSize || 0
                        onMoved: tileSettings.saveSetting("artSize", Math.round(value))
                        implicitWidth: 120
                    }
                    Text {
                        text: artSizeSlider.value === 0 ? "Auto" : Math.round(artSizeSlider.value) + "px"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Progress Bar"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Show time labels"
                Switch {
                    checked: tileSettings.settings.showTimeLabels !== false
                    onToggled: tileSettings.saveSetting("showTimeLabels", checked)
                }
            }

            SettingsRow {
                label: "Time label scale"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: timeLabelScaleSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.timeLabelScale || 1.0
                        onMoved: tileSettings.saveSetting("timeLabelScale", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(timeLabelScaleSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Bar thickness"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: progressThicknessSlider
                        from: 0.5; to: 5.0; stepSize: 0.25
                        value: tileSettings.settings.progressThickness || 1.0
                        onMoved: tileSettings.saveSetting("progressThickness", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(progressThicknessSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob size"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: progressKnobSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.progressKnobSize || 1.0
                        onMoved: tileSettings.saveSetting("progressKnobSize", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(progressKnobSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob shape"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "pill", label: "Pill" },
                            { value: "circle", label: "Circle" },
                            { value: "square", label: "Square" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.progressKnobShape || "pill") === modelData.value
                            onClicked: tileSettings.saveSetting("progressKnobShape", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Transport Controls"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Button scale"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: buttonScaleSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.buttonScale || 1.0
                        onMoved: tileSettings.saveSetting("buttonScale", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(buttonScaleSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
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
                font.pixelSize: 15 * tileSettings.ts
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
                font.pixelSize: 15 * tileSettings.ts
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
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Show controls"
                Switch {
                    checked: tileSettings.settings.showControls !== false
                    onToggled: tileSettings.saveSetting("showControls", checked)
                }
            }

            SettingsRow {
                label: "Show mode toggle"
                Switch {
                    checked: tileSettings.settings.showModeToggle !== false
                    onToggled: tileSettings.saveSetting("showModeToggle", checked)
                }
            }
        }

        // System Monitor
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "system_monitor"
            Layout.fillWidth: true

            Text {
                text: "System Monitor"
                color: themeManager.accentColor
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Show CPU bar"
                Switch {
                    checked: tileSettings.settings.showCpuBar !== false
                    onToggled: tileSettings.saveSetting("showCpuBar", checked)
                }
            }

            SettingsRow {
                label: "Show RAM bar"
                Switch {
                    checked: tileSettings.settings.showRamBar !== false
                    onToggled: tileSettings.saveSetting("showRamBar", checked)
                }
            }

            SettingsRow {
                label: "Show RAM detail"
                Switch {
                    checked: tileSettings.settings.showRamDetail !== false
                    onToggled: tileSettings.saveSetting("showRamDetail", checked)
                }
            }
        }

        // Brightness
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "brightness"
            Layout.fillWidth: true

            Text {
                text: "Brightness"
                color: themeManager.accentColor
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Show percent"
                Switch {
                    checked: tileSettings.settings.showPercent !== false
                    onToggled: tileSettings.saveSetting("showPercent", checked)
                }
            }

            SettingsRow {
                label: "Show icon"
                Switch {
                    checked: tileSettings.settings.showIcon !== false
                    onToggled: tileSettings.saveSetting("showIcon", checked)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Slider"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Track thickness"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: brightThicknessSlider
                        from: 0.5; to: 5.0; stepSize: 0.25
                        value: tileSettings.settings.sliderThickness || 1.0
                        onMoved: tileSettings.saveSetting("sliderThickness", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(brightThicknessSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob size"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: brightKnobSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.knobSize || 1.0
                        onMoved: tileSettings.saveSetting("knobSize", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(brightKnobSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob shape"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "pill", label: "Pill" },
                            { value: "circle", label: "Circle" },
                            { value: "square", label: "Square" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.knobShape || "pill") === modelData.value
                            onClicked: tileSettings.saveSetting("knobShape", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Colors"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            // Color picker rows for brightness slider
            Repeater {
                model: [
                    { key: "iconColor", label: "Icon" },
                    { key: "barColor", label: "Bar fill" },
                    { key: "knobColor", label: "Knob" },
                    { key: "percentColor", label: "Percent" }
                ]
                ColumnLayout {
                    id: brightColorRow
                    required property var modelData
                    property string colorKey: modelData.key
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: brightColorRow.modelData.label
                        color: themeManager.textColor
                        font.pixelSize: 13 * tileSettings.ts
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { hex: "", label: "Default" },
                                { hex: "#ffffff", label: "White" },
                                { hex: "#4488ff", label: "Blue" },
                                { hex: "#FFD54F", label: "Yellow" },
                                { hex: "#ff4444", label: "Red" },
                                { hex: "#44dd66", label: "Green" },
                                { hex: "#ff8844", label: "Orange" },
                                { hex: "#cc44ff", label: "Purple" },
                                { hex: "#44dddd", label: "Cyan" },
                                { hex: "#ff66aa", label: "Pink" }
                            ]
                            Rectangle {
                                required property var modelData
                                width: 22; height: 22; radius: 11
                                color: modelData.hex === "" ? themeManager.overlayColor : modelData.hex
                                border.width: (tileSettings.settings[brightColorRow.colorKey] || "") === modelData.hex ? 2 : 1
                                border.color: (tileSettings.settings[brightColorRow.colorKey] || "") === modelData.hex
                                    ? themeManager.accentColor : themeManager.borderColor
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.hex === "" ? "D" : ""
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10 * tileSettings.ts; font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: tileSettings.saveSetting(brightColorRow.colorKey, parent.modelData.hex)
                                }
                            }
                        }

                        TextField {
                            text: tileSettings.settings[brightColorRow.colorKey] || ""
                            placeholderText: "#hex"
                            onEditingFinished: tileSettings.saveSetting(brightColorRow.colorKey, text)
                            width: 70
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 24; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Monitors"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            Text {
                visible: {
                    var mons = tileSettings.settings.brightnessMonitors
                    return !mons || mons.length === 0
                }
                text: "First available display (add monitors to enable swipe)"
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * tileSettings.ts
                font.italic: true
            }

            // List of configured monitors
            Repeater {
                id: brightMonitorRepeater
                model: {
                    var mons = tileSettings.settings.brightnessMonitors
                    if (!mons || mons.length === 0) return []
                    if (typeof mons === "string") {
                        try { return JSON.parse(mons) } catch(e) { return [] }
                    }
                    return mons
                }
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6

                    LucideIcon {
                        width: 16; height: 16
                        source: "qrc:/icons/lucide/monitor.svg"
                        color: themeManager.secondaryTextColor
                    }

                    Text {
                        text: parent.modelData.name || "Display " + parent.modelData.id
                        color: themeManager.textColor
                        font.pixelSize: 12 * tileSettings.ts
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "X"
                        flat: true
                        onClicked: {
                            var mons = tileSettings.settings.brightnessMonitors || []
                            if (typeof mons === "string") {
                                try { mons = JSON.parse(mons) } catch(e) { mons = [] }
                            }
                            mons = mons.filter(function(_, i) { return i !== parent.index })
                            tileSettings.saveSetting("brightnessMonitors", mons)
                        }
                        contentItem: Text {
                            text: parent.text; color: themeManager.errorColor
                            font.pixelSize: 12 * tileSettings.ts
                        }
                        background: Rectangle {
                            implicitWidth: 24; implicitHeight: 22; radius: 4
                            color: parent.hovered ? themeManager.overlayColor : "transparent"
                        }
                    }
                }
            }

            Button {
                text: "+ Add Monitor"
                flat: true
                onClicked: monitorPickerPopup.open()
                contentItem: Text {
                    text: parent.text
                    color: themeManager.accentColor
                    font.pixelSize: 12 * tileSettings.ts
                }
                background: Rectangle {
                    implicitWidth: 110; implicitHeight: 28; radius: 6
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }

            // Monitor picker popup
            Popup {
                id: monitorPickerPopup
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: 320; height: 300
                modal: true; focus: true

                background: Rectangle {
                    color: themeManager.backgroundColor
                    border.width: 1; border.color: themeManager.borderColor; radius: 12
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Text {
                        text: "Add Monitor"
                        color: themeManager.textColor
                        font.pixelSize: 15 * tileSettings.ts; font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: brightnessService ? brightnessService.displays : []

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width; height: 40
                            color: monItemArea.containsMouse ? themeManager.overlayColor : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8

                                LucideIcon {
                                    width: 18; height: 18
                                    source: "qrc:/icons/lucide/monitor.svg"
                                    color: themeManager.textColor
                                }

                                Text {
                                    text: parent.parent.modelData.name || ("Display " + parent.parent.modelData.id)
                                    color: themeManager.textColor
                                    font.pixelSize: 13 * tileSettings.ts
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: monItemArea
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    var monId = parent.modelData.id
                                    var monName = parent.modelData.name || ("Display " + monId)
                                    var mons = tileSettings.settings.brightnessMonitors || []
                                    if (typeof mons === "string") {
                                        try { mons = JSON.parse(mons) } catch(e) { mons = [] }
                                    }
                                    var newMons = []
                                    for (var i = 0; i < mons.length; i++) newMons.push(mons[i])
                                    newMons.push({ id: monId, name: monName })
                                    tileSettings.saveSetting("brightnessMonitors", newMons)
                                    monitorPickerPopup.close()
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }

        // Audio Mixer
        ColumnLayout {
            spacing: 10
            visible: tileSettings.tileType === "audio_mixer"
            Layout.fillWidth: true

            Text {
                text: "Audio Mixer"
                color: themeManager.accentColor
                font.pixelSize: 15 * tileSettings.ts
                font.bold: true
            }

            SettingsRow {
                label: "Show mic slider"
                Switch {
                    checked: tileSettings.settings.showMic !== false
                    onToggled: tileSettings.saveSetting("showMic", checked)
                }
            }

            SettingsRow {
                label: "Show EQ presets"
                Switch {
                    checked: tileSettings.settings.showEq !== false
                    onToggled: tileSettings.saveSetting("showEq", checked)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Collapsed Tile"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            // Primary group picker
            Text {
                text: "Primary group (shown when collapsed)"
                color: themeManager.textColor
                font.pixelSize: 12 * tileSettings.ts
            }

            Flow {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: audioMixerService ? audioMixerService.groupNames() : []

                    Rectangle {
                        required property string modelData
                        required property int index
                        width: pgBtnText.implicitWidth + 16 * tileSettings.ts
                        height: 26 * tileSettings.ts
                        radius: 6
                        color: (tileSettings.settings.primaryGroup || 0) === index
                               ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.2)
                               : "transparent"
                        border.width: 1
                        border.color: (tileSettings.settings.primaryGroup || 0) === index
                                      ? themeManager.accentColor : themeManager.borderColor

                        Text {
                            id: pgBtnText
                            anchors.centerIn: parent
                            text: modelData
                            color: (tileSettings.settings.primaryGroup || 0) === index
                                   ? themeManager.accentColor : themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: tileSettings.saveSetting("primaryGroup", index)
                        }
                    }
                }
            }

            // EQ position toggle
            SettingsRow {
                label: "EQ position in overlay"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "left", label: "Left" },
                            { value: "right", label: "Right" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.eqPosition || "left") === modelData.value
                            onClicked: tileSettings.saveSetting("eqPosition", modelData.value)
                            contentItem: Text {
                                text: parent.text
                                color: parent.highlighted ? themeManager.accentColor : themeManager.textColor
                                font.pixelSize: 13 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Groups"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            // List of groups
            Repeater {
                id: mixerGroupRepeater
                model: audioMixerService ? audioMixerService.groups : []

                ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        TextField {
                            text: modelData.name || ""
                            color: themeManager.textColor
                            font.pixelSize: 13 * tileSettings.ts
                            font.bold: true
                            Layout.fillWidth: true
                            onEditingFinished: audioMixerService.renameGroup(index, text)
                            background: Rectangle {
                                implicitHeight: 28; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }

                        Button {
                            text: "X"
                            flat: true
                            visible: !(modelData.isGeneral || false)
                            onClicked: audioMixerService.removeGroup(index)
                            contentItem: Text {
                                text: parent.text; color: themeManager.errorColor
                                font.pixelSize: 12 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 24; implicitHeight: 22; radius: 4
                                color: parent.hovered ? themeManager.overlayColor : "transparent"
                            }
                        }
                    }

                    // List of apps in this group
                    Repeater {
                        model: modelData.apps || []
                        RowLayout {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            spacing: 4

                            LucideIcon {
                                width: 14; height: 14
                                source: "qrc:/icons/lucide/music.svg"
                                color: themeManager.secondaryTextColor
                            }

                            Text {
                                text: modelData
                                color: themeManager.textColor
                                font.pixelSize: 12 * tileSettings.ts
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Button {
                                text: "x"
                                flat: true
                                onClicked: audioMixerService.removeAppFromGroup(parent.parent.index, modelData)
                                contentItem: Text {
                                    text: parent.text; color: themeManager.errorColor
                                    font.pixelSize: 11 * tileSettings.ts
                                }
                                background: Rectangle {
                                    implicitWidth: 20; implicitHeight: 18; radius: 4
                                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                                }
                            }
                        }
                    }

                    // Add app button
                    Button {
                        text: "+ Add App"
                        flat: true
                        onClicked: {
                            tileSettings.mixerAppPickerGroupIdx = index
                            mixerAppPickerPopup.open()
                        }
                        contentItem: Text {
                            text: parent.text
                            color: themeManager.accentColor
                            font.pixelSize: 11 * tileSettings.ts
                        }
                        background: Rectangle {
                            implicitWidth: 80; implicitHeight: 24; radius: 6
                            color: parent.hovered ? themeManager.overlayColor : "transparent"
                            border.width: 1; border.color: themeManager.borderColor
                        }
                        Layout.leftMargin: 12
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; opacity: 0.4 }
                }
            }

            Button {
                text: "+ Add Group"
                flat: true
                onClicked: audioMixerService.addGroup("New Group")
                contentItem: Text {
                    text: parent.text
                    color: themeManager.accentColor
                    font.pixelSize: 12 * tileSettings.ts
                }
                background: Rectangle {
                    implicitWidth: 110; implicitHeight: 28; radius: 6
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                    border.width: 1; border.color: themeManager.borderColor
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Slider"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            SettingsRow {
                label: "Track thickness"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: mixerThicknessSlider
                        from: 0.5; to: 5.0; stepSize: 0.25
                        value: tileSettings.settings.sliderThickness || 1.0
                        onMoved: tileSettings.saveSetting("sliderThickness", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(mixerThicknessSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob size"
                RowLayout {
                    spacing: 8
                    Slider {
                        id: mixerKnobSlider
                        from: 0.5; to: 3.0; stepSize: 0.25
                        value: tileSettings.settings.knobSize || 1.0
                        onMoved: tileSettings.saveSetting("knobSize", Math.round(value * 100) / 100)
                        implicitWidth: 120
                    }
                    Text {
                        text: Math.round(mixerKnobSlider.value * 100) + "%"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 12 * tileSettings.ts
                    }
                }
            }

            SettingsRow {
                label: "Knob shape"
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { value: "pill", label: "Pill" },
                            { value: "circle", label: "Circle" },
                            { value: "square", label: "Square" }
                        ]
                        Button {
                            required property var modelData
                            text: modelData.label; flat: true
                            highlighted: (tileSettings.settings.knobShape || "pill") === modelData.value
                            onClicked: tileSettings.saveSetting("knobShape", modelData.value)
                            contentItem: Text { text: parent.text; color: parent.highlighted ? themeManager.accentColor : themeManager.textColor; font.pixelSize: 13 * tileSettings.ts }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 26; radius: 6
                                color: parent.highlighted ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g, themeManager.accentColor.b, 0.15) : "transparent"
                                border.width: 1; border.color: parent.highlighted ? themeManager.accentColor : themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: themeManager.borderColor; Layout.topMargin: 4 }

            Text {
                text: "Colors"
                color: themeManager.secondaryTextColor
                font.pixelSize: 13 * tileSettings.ts
            }

            Repeater {
                model: [
                    { key: "iconColor", label: "Icon" },
                    { key: "barColor", label: "Bar fill" },
                    { key: "knobColor", label: "Knob" },
                    { key: "percentColor", label: "Percent" }
                ]
                ColumnLayout {
                    id: mixerColorRow
                    required property var modelData
                    property string colorKey: modelData.key
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: mixerColorRow.modelData.label
                        color: themeManager.textColor
                        font.pixelSize: 13 * tileSettings.ts
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { hex: "", label: "Default" },
                                { hex: "#ffffff", label: "White" },
                                { hex: "#4488ff", label: "Blue" },
                                { hex: "#FFD54F", label: "Yellow" },
                                { hex: "#ff4444", label: "Red" },
                                { hex: "#44dd66", label: "Green" },
                                { hex: "#ff8844", label: "Orange" },
                                { hex: "#cc44ff", label: "Purple" },
                                { hex: "#44dddd", label: "Cyan" },
                                { hex: "#ff66aa", label: "Pink" }
                            ]
                            Rectangle {
                                required property var modelData
                                width: 22; height: 22; radius: 11
                                color: modelData.hex === "" ? themeManager.overlayColor : modelData.hex
                                border.width: (tileSettings.settings[mixerColorRow.colorKey] || "") === modelData.hex ? 2 : 1
                                border.color: (tileSettings.settings[mixerColorRow.colorKey] || "") === modelData.hex
                                    ? themeManager.accentColor : themeManager.borderColor
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.hex === "" ? "D" : ""
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 10 * tileSettings.ts; font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: tileSettings.saveSetting(mixerColorRow.colorKey, parent.modelData.hex)
                                }
                            }
                        }

                        TextField {
                            text: tileSettings.settings[mixerColorRow.colorKey] || ""
                            placeholderText: "#hex"
                            onEditingFinished: tileSettings.saveSetting(mixerColorRow.colorKey, text)
                            width: 70
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 24; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }
                    }
                }
            }

            Popup {
                id: mixerAppPickerPopup
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: 320; height: 350
                modal: true; focus: true

                background: Rectangle {
                    color: themeManager.backgroundColor
                    border.width: 1; border.color: themeManager.borderColor; radius: 12
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Text {
                        text: "Add App to Group"
                        color: themeManager.textColor
                        font.pixelSize: 15 * tileSettings.ts; font.bold: true
                    }

                    // Manual entry
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        TextField {
                            id: mixerManualAppField
                            Layout.fillWidth: true
                            placeholderText: "App name..."
                            color: themeManager.textColor
                            font.pixelSize: 12 * tileSettings.ts
                            background: Rectangle {
                                implicitHeight: 28; radius: 4; color: "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }

                        Button {
                            text: "Add"
                            flat: true
                            enabled: mixerManualAppField.text.length > 0
                            onClicked: {
                                audioMixerService.addAppToGroup(tileSettings.mixerAppPickerGroupIdx, mixerManualAppField.text)
                                mixerManualAppField.text = ""
                                mixerAppPickerPopup.close()
                            }
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? themeManager.accentColor : themeManager.secondaryTextColor
                                font.pixelSize: 12 * tileSettings.ts
                            }
                            background: Rectangle {
                                implicitWidth: 50; implicitHeight: 28; radius: 6
                                color: parent.hovered ? themeManager.overlayColor : "transparent"
                                border.width: 1; border.color: themeManager.borderColor
                            }
                        }
                    }

                    Text {
                        text: "Running Apps"
                        color: themeManager.secondaryTextColor
                        font.pixelSize: 11 * tileSettings.ts
                    }

                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: audioMixerService ? audioMixerService.activeAudioApps() : []

                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            width: ListView.view.width; height: 36
                            color: appItemArea.containsMouse ? themeManager.overlayColor : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8

                                LucideIcon {
                                    width: 16; height: 16
                                    source: "qrc:/icons/lucide/music.svg"
                                    color: themeManager.textColor
                                }

                                Text {
                                    text: modelData
                                    color: themeManager.textColor
                                    font.pixelSize: 13 * tileSettings.ts
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: appItemArea
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    audioMixerService.addAppToGroup(tileSettings.mixerAppPickerGroupIdx, modelData)
                                    mixerAppPickerPopup.close()
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }

        // Spacer
        Item { Layout.fillHeight: true }
    }
}
