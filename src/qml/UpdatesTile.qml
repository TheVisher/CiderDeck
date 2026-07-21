import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: updatesTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0
    readonly property color statusColor: updateService.totalCount > 0
                                         ? "#f2c14e"
                                         : themeManager.successColor

    function packageName(line) {
        if (!line)
            return ""
        var tabParts = line.split("\t")
        if (tabParts.length > 1)
            return tabParts[1] + (tabParts.length > 2 ? "  " + tabParts[2] : "")
        return line.split(" ")[0]
    }

    Item {
        id: normalContent
        anchors.fill: parent
        anchors.margins: 14
        visible: !updateService.terminalActive

        ColumnLayout {
            anchors.fill: parent
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                Rectangle {
                    width: 4
                    height: 18
                    radius: 2
                    color: updatesTile.statusColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "UPDATES"
                        color: themeManager.textColor
                        font.pixelSize: 13 * updatesTile.contentScale
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: updateService.checking
                              ? "Checking package sources..."
                              : updateService.errorMessage
                                ? updateService.errorMessage
                                : updateService.totalCount === 0
                                  ? "System is current"
                                  : updateService.totalCount + (updateService.totalCount === 1
                                      ? " package available" : " packages available")
                        color: updateService.errorMessage ? themeManager.errorColor
                                                         : themeManager.secondaryTextColor
                        font.pixelSize: 11 * updatesTile.contentScale
                        elide: Text.ElideRight
                    }
                }

                IconTouchButton {
                    Layout.preferredWidth: 38 * updatesTile.contentScale
                    Layout.preferredHeight: 38 * updatesTile.contentScale
                    source: "qrc:/icons/lucide/rotate-ccw.svg"
                    iconSize: 17 * updatesTile.contentScale
                    enabled: !updateService.checking
                    onClicked: updateService.refresh()

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 850
                        loops: Animation.Infinite
                        running: updateService.checking
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 54 * updatesTile.contentScale
                spacing: 0

                Repeater {
                    model: [
                        { name: "OFFICIAL", count: updateService.officialCount, color: themeManager.accentColor },
                        { name: "AUR", count: updateService.aurCount, color: "#f2c14e" },
                        { name: "FLATPAK", count: updateService.flatpakCount, color: "#62d2a2" }
                    ]

                    Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.count
                                color: modelData.color
                                font.pixelSize: 24 * updatesTile.contentScale
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                color: themeManager.secondaryTextColor
                                font.pixelSize: 9 * updatesTile.contentScale
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 32
                            color: themeManager.borderColor
                            visible: index < 2
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3
                visible: updatesTile.sizeClass !== "tiny"

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: updateService.hasChecked
                             && updateService.totalCount === 0
                             && !updateService.errorMessage

                    Row {
                        anchors.centerIn: parent
                        spacing: 9

                        LucideIcon {
                            width: 22 * updatesTile.contentScale
                            height: width
                            source: "qrc:/icons/lucide/check.svg"
                            color: themeManager.successColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "No updates available"
                            color: themeManager.secondaryTextColor
                            font.pixelSize: 12 * updatesTile.contentScale
                        }
                    }
                }

                Repeater {
                    model: updateService.allUpdates.slice(0, 3)

                    RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 7

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: updatesTile.statusColor
                        }
                        Text {
                            Layout.fillWidth: true
                            text: updatesTile.packageName(modelData)
                            color: themeManager.textColor
                            font.pixelSize: 11 * updatesTile.contentScale
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    visible: updateService.totalCount > 0 || !updateService.hasChecked
                }
            }

            Rectangle {
                id: updateButton
                Layout.fillWidth: true
                Layout.preferredHeight: 42 * updatesTile.contentScale
                radius: 6
                color: updateMouse.pressed
                       ? Qt.rgba(updatesTile.statusColor.r, updatesTile.statusColor.g,
                                 updatesTile.statusColor.b, 0.32)
                       : Qt.rgba(updatesTile.statusColor.r, updatesTile.statusColor.g,
                                 updatesTile.statusColor.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(updatesTile.statusColor.r, updatesTile.statusColor.g,
                                      updatesTile.statusColor.b, 0.55)
                opacity: updateMouse.enabled ? 1 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: 9

                    LucideIcon {
                        width: 17 * updatesTile.contentScale
                        height: width
                        source: "qrc:/icons/lucide/terminal.svg"
                        color: updatesTile.statusColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: updateService.updateRunning ? "Update terminal open"
                              : updateService.totalCount > 0 ? "Update all" : "All current"
                        color: themeManager.textColor
                        font.pixelSize: 12 * updatesTile.contentScale
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: updateMouse
                    anchors.fill: parent
                    enabled: updateService.totalCount > 0
                             && !updateService.checking
                             && !updateService.updateRunning
                    onClicked: updateService.updateAll()
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: updateService.hasChecked ? "Checked " + updateService.lastChecked : "Not checked yet"
                color: themeManager.secondaryTextColor
                font.pixelSize: 9 * updatesTile.contentScale
            }
        }
    }

    FocusScope {
        id: terminalView
        anchors.fill: parent
        anchors.margins: 8
        visible: updateService.terminalActive
        focus: visible

        TapHandler {
            onTapped: terminalView.forceActiveFocus()
        }

        function updateTerminalSize() {
            updateService.setTerminalSize(
                Math.max(40, Math.floor(terminalViewport.width / (7.2 * updatesTile.contentScale))),
                Math.max(8, Math.floor(terminalViewport.height / (15 * updatesTile.contentScale))))
        }

        function scrollToBottom() {
            terminalScroll.contentY = Math.max(
                0, terminalScroll.contentHeight - terminalScroll.height)
        }

        onVisibleChanged: {
            if (visible) {
                forceActiveFocus()
                updateTerminalSize()
                Qt.callLater(scrollToBottom)
            }
        }

        Keys.onPressed: (event) => {
            var input = ""
            var control = (event.modifiers & Qt.ControlModifier) !== 0
            if (control && event.key === Qt.Key_C) input = "\x03"
            else if (control && event.key === Qt.Key_D) input = "\x04"
            else if (control && event.key === Qt.Key_Z) input = "\x1a"
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) input = "\n"
            else if (event.key === Qt.Key_Backspace) input = "\x7f"
            else if (event.key === Qt.Key_Tab) input = "\t"
            else if (event.key === Qt.Key_Escape) input = "\x1b"
            else if (event.key === Qt.Key_Up) input = "\x1b[A"
            else if (event.key === Qt.Key_Down) input = "\x1b[B"
            else if (event.key === Qt.Key_Right) input = "\x1b[C"
            else if (event.key === Qt.Key_Left) input = "\x1b[D"
            else if (!control && event.text !== "") input = event.text

            if (input !== "") {
                updateService.sendTerminalInput(input)
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Qt.rgba(0.015, 0.022, 0.032, 0.96)
            border.width: 1
            border.color: Qt.rgba(themeManager.accentColor.r,
                                  themeManager.accentColor.g,
                                  themeManager.accentColor.b, 0.55)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: themeManager.accentColor
                }
                Text {
                    Layout.fillWidth: true
                    text: "CIDERDECK SYSTEM UPDATE"
                    color: themeManager.textColor
                    font.pixelSize: 11 * updatesTile.contentScale
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                }
                Rectangle {
                    id: cancelButton
                    width: cancelLabel.implicitWidth + 18
                    height: 26 * updatesTile.contentScale
                    radius: 5
                    color: cancelMouse.pressed
                           ? Qt.rgba(0.9, 0.2, 0.2, 0.30)
                           : Qt.rgba(0.9, 0.2, 0.2, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(0.95, 0.3, 0.3, 0.55)

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: themeManager.textColor
                        font.pixelSize: 10 * updatesTile.contentScale
                    }
                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        onClicked: updateService.cancelUpdate()
                    }
                }
            }

            Rectangle {
                id: terminalViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: "#090d13"
                clip: true

                onWidthChanged: terminalView.updateTerminalSize()
                onHeightChanged: terminalView.updateTerminalSize()

                Flickable {
                    id: terminalScroll
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    contentWidth: width
                    contentHeight: terminalText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    TextEdit {
                        id: terminalText
                        width: terminalScroll.width
                        text: updateService.terminalOutput
                        color: "#e8edf5"
                        selectionColor: themeManager.accentColor
                        selectedTextColor: "white"
                        font.family: "monospace"
                        font.pixelSize: 11 * updatesTile.contentScale
                        wrapMode: TextEdit.WrapAnywhere
                        readOnly: true
                        selectByMouse: true
                        activeFocusOnPress: false
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Keyboard input goes directly to the updater · Ctrl+C also cancels the current command"
                color: themeManager.secondaryTextColor
                font.pixelSize: 8.5 * updatesTile.contentScale
                elide: Text.ElideRight
            }
        }

        Connections {
            target: updateService
            function onTerminalOutputChanged() {
                Qt.callLater(terminalView.scrollToBottom)
            }
            function onUpdated() {
                if (updateService.terminalActive)
                    Qt.callLater(terminalView.forceActiveFocus)
            }
        }
    }
}
