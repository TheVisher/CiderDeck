import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsPanel

    property bool isOpen: false
    property string mode: "general" // "general" or "tile"
    property string editingTileId: ""

    visible: isOpen
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b, 0.95)
    border.width: 1
    border.color: themeManager.borderColor
    radius: 16

    width: 420
    height: parent.height - 32
    anchors.right: parent.right
    anchors.rightMargin: isOpen ? 16 : -width
    anchors.verticalCenter: parent.verticalCenter

    Behavior on anchors.rightMargin {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    // Block clicks from passing through
    MouseArea {
        anchors.fill: parent
        onClicked: {} // absorb
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: settingsPanel.mode === "tile" ? "Tile Settings" : "Settings"
                color: themeManager.textColor
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: "X"
                flat: true
                onClicked: settingsPanel.isOpen = false
                contentItem: Text {
                    text: "X"
                    color: themeManager.textColor
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: parent.hovered ? themeManager.overlayColor : "transparent"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: themeManager.borderColor
        }

        // Content
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            sourceComponent: settingsPanel.mode === "tile" ? tileSettingsComponent : generalSettingsComponent
        }
    }

    Component {
        id: generalSettingsComponent
        GeneralSettings {}
    }

    Component {
        id: tileSettingsComponent
        TileSettings {
            tileId: settingsPanel.editingTileId
        }
    }

    function openGeneral() {
        mode = "general"
        editingTileId = ""
        isOpen = true
    }

    function openTile(tileId) {
        mode = "tile"
        editingTileId = tileId
        isOpen = true
    }

    function close() {
        isOpen = false
    }
}
