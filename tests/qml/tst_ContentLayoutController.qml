import QtQuick
import QtTest
import "../../src/qml"

TestCase {
    id: root
    name: "ContentLayoutController"
    when: windowShown

    property string contentEditConstraint: ""
    property string contentEditElement: ""
    property string contentValidatorOwner: ""
    property var contentScaleValidator: null
    property var contentItemValueValidator: null
    property var savedSettings: ({})
    property var latestTileSettings: ({ contentScale: 1 })

    function clearContentValidators(owner) {
        if (contentValidatorOwner !== owner) return
        contentValidatorOwner = ""
        contentScaleValidator = null
        contentItemValueValidator = null
    }

    QtObject {
        id: settingsPanel
        property bool isOpen: false
        property string editingTileId: ""
    }

    QtObject {
        id: tileGridModel
        function getTileById(tileId) {
            return { settings: root.latestTileSettings }
        }
    }

    QtObject {
        id: deckConfig
        function updateTile(tileId, changes) {
            root.savedSettings = changes.settings
        }
    }

    Item {
        id: tile
        width: 220
        height: 120

        Item {
            id: canvas
            width: 200
            height: 100

            Item {
                id: contentItem
                width: 40
                height: 20
                x: controller.hasSavedValue("text", "x")
                   ? controller.elementX("text") : 0
                y: controller.hasSavedValue("text", "y")
                   ? controller.elementY("text") : 0
            }
        }

        ContentLayoutController {
            id: controller
            tile: tile
            canvas: canvas
            tileId: "test-tile"
            settings: ({ contentLayout: {
                text: { x: 0.4, y: 0.4, anchorX: "center", anchorY: "center" }
            } })
            elements: [
                { id: "text", label: "Text", scale: 1, textScale: 1, visible: true }
            ]
            itemForId: function(elementId) {
                return elementId === "text" ? contentItem : null
            }
        }
    }

    function init() {
        contentItem.width = 40
        contentItem.height = 20
        root.savedSettings = ({})
        root.latestTileSettings = ({ contentScale: 1 })
        wait(0)
    }

    function test_centerAnchorTracksChangingItemSize() {
        compare(contentItem.x, 80)
        compare(contentItem.y, 40)

        contentItem.width = 80
        contentItem.height = 40
        wait(0)

        compare(contentItem.x, 60)
        compare(contentItem.y, 30)
    }

    function test_centerSnapIsPersistedAndUsesLatestSettings() {
        root.latestTileSettings = ({ contentScale: 2, recentSetting: true })

        controller.beginElementDrag("text", contentItem, contentItem.x, contentItem.y)
        controller.updateElementDrag(80, 0)
        verify(controller.showVerticalGuide)
        verify(!controller.showHorizontalGuide)
        controller.endElementDrag()

        compare(root.savedSettings.contentScale, 2)
        compare(root.savedSettings.recentSetting, true)
        compare(root.savedSettings.contentLayout.text.anchorX, "center")
        verify(root.savedSettings.contentLayout.text.anchorY === undefined)
    }
}
