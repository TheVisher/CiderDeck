import QtQuick
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
        anchors.fill: parent
        anchors.margins: 14

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
}
