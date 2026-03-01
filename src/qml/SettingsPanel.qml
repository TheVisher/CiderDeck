import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsPanel

    property bool isOpen: false
    property string mode: "general" // "general" or "tile"
    property string editingTileId: ""

    readonly property real ts: deckConfig.settingsTextScale

    visible: isOpen
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b, 0.95)
    border.width: 1
    border.color: themeManager.borderColor
    radius: 16

    width: 520
    height: parent.height - 32
    y: (parent.height - height) / 2
    x: parent.width - width - 16

    Behavior on x {
        id: xBehavior
        enabled: true
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    onIsOpenChanged: {
        if (isOpen) {
            x = parent.width - width - 16
        } else {
            x = parent.width + 16
        }
    }

    // Drag handle + click absorber
    MouseArea {
        id: dragArea
        anchors.fill: parent

        property bool isDragging: false
        property real startGlobalX: 0
        property real startPanelX: 0

        onPressed: (mouse) => {
            // Only drag from the top 48px (header area)
            if (mouse.y <= 48) {
                isDragging = true
                var global = mapToItem(settingsPanel.parent, mouse.x, mouse.y)
                startGlobalX = global.x
                startPanelX = settingsPanel.x
                xBehavior.enabled = false
            }
        }
        onPositionChanged: (mouse) => {
            if (isDragging) {
                var global = mapToItem(settingsPanel.parent, mouse.x, mouse.y)
                var newX = startPanelX + (global.x - startGlobalX)
                // Clamp so panel stays at least 60px on screen
                settingsPanel.x = Math.max(-settingsPanel.width + 60,
                    Math.min(settingsPanel.parent.width - 60, newX))
            }
        }
        onReleased: {
            isDragging = false
            xBehavior.enabled = true
        }
        onCanceled: {
            isDragging = false
            xBehavior.enabled = true
        }
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
                font.pixelSize: 20 * settingsPanel.ts
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
                    font.pixelSize: 16 * settingsPanel.ts
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
