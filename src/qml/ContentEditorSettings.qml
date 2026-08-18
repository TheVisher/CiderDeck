import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: editor

    required property var settingsHost
    property string editorName: "Tile"
    property string initialElement: settingsHost.contentElements.length > 0
                                    ? settingsHost.contentElements[0].id : ""

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: "Content layout"
        color: themeManager.accentColor
        font.pixelSize: 15 * editor.settingsHost.ts
        font.bold: true
    }

    SettingsRow {
        label: "Allow overlap"
        visible: root.contentEditTileId === editor.settingsHost.tileId
        Switch {
            checked: editor.settingsHost.contentOverlapAllowed()
            onToggled: editor.settingsHost.saveSetting("allowContentOverlap", checked)
        }
    }

    Button {
        Layout.fillWidth: true
        text: root.contentEditTileId === editor.settingsHost.tileId
              ? "Done Editing " + editor.editorName + " Content"
              : "Edit " + editor.editorName + " Content Layout"
        onClicked: {
            if (root.contentEditTileId === editor.settingsHost.tileId)
                root.endContentEdit()
            else
                root.beginContentEdit(editor.settingsHost.tileId, editor.initialElement)
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.contentEditTileId === editor.settingsHost.tileId
        text: "Drag the outlined items inside the tile. Center lines and nearby item edges snap into alignment. Hidden items remain listed here so they can be restored."
        color: themeManager.secondaryTextColor
        font.pixelSize: 12 * editor.settingsHost.ts
        wrapMode: Text.WordWrap
    }

    Text {
        Layout.fillWidth: true
        visible: root.contentEditTileId === editor.settingsHost.tileId
                 && root.contentEditConstraint !== ""
        text: root.contentEditConstraint
        color: themeManager.errorColor
        font.pixelSize: 12 * editor.settingsHost.ts
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }

    Flow {
        Layout.fillWidth: true
        spacing: 5
        visible: root.contentEditTileId === editor.settingsHost.tileId

        Repeater {
            model: editor.settingsHost.contentElements
            Button {
                required property var modelData
                text: modelData.label
                      + (editor.settingsHost.contentElementVisible(modelData.id)
                         ? "" : " (hidden)")
                flat: true
                highlighted: root.contentEditElement === modelData.id
                onClicked: root.contentEditElement = modelData.id
            }
        }
    }

    SettingsRow {
        label: "Show item"
        visible: root.contentEditTileId === editor.settingsHost.tileId
        Switch {
            checked: editor.settingsHost.contentElementVisible(root.contentEditElement)
            onToggled: editor.settingsHost.saveContentElementVisible(
                root.contentEditElement, checked)
        }
    }

    SettingsRow {
        label: editor.settingsHost.contentElementSizeLabel(root.contentEditElement)
        visible: root.contentEditTileId === editor.settingsHost.tileId
        RowLayout {
            spacing: 8
            Slider {
                id: itemScaleSlider
                from: 0.5; to: 3.0; stepSize: 0.05
                onMoved: value = editor.settingsHost.saveContentElementValue(
                    root.contentEditElement, "scale", Math.round(value * 100) / 100)
                implicitWidth: 150

                Binding on value {
                    when: !itemScaleSlider.pressed
                    value: editor.settingsHost.contentElementValue(
                        root.contentEditElement, "scale", 1)
                }
            }
            Text {
                text: Math.round(itemScaleSlider.value * 100) + "%"
                color: themeManager.secondaryTextColor
                font.pixelSize: 12 * editor.settingsHost.ts
            }
        }
    }

    SettingsRow {
        label: "Text size"
        visible: root.contentEditTileId === editor.settingsHost.tileId
                 && editor.settingsHost.contentElementHasText(root.contentEditElement)
        RowLayout {
            spacing: 8
            Slider {
                id: textScaleSlider
                from: 0.5; to: 3.0; stepSize: 0.05
                onMoved: value = editor.settingsHost.saveContentElementValue(
                    root.contentEditElement, "textScale", Math.round(value * 100) / 100)
                implicitWidth: 150

                Binding on value {
                    when: !textScaleSlider.pressed
                    value: editor.settingsHost.contentElementValue(
                        root.contentEditElement, "textScale", 1)
                }
            }
            Text {
                text: Math.round(textScaleSlider.value * 100) + "%"
                color: themeManager.secondaryTextColor
                font.pixelSize: 12 * editor.settingsHost.ts
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.contentEditTileId === editor.settingsHost.tileId
        Button {
            text: "Reset Selected"
            onClicked: editor.settingsHost.resetContentElement(root.contentEditElement)
        }
        Button {
            text: "Reset Entire Layout"
            onClicked: editor.settingsHost.saveSetting("contentLayout", ({}))
        }
    }
}
