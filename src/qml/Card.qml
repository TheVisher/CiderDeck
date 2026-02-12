import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: card

    // Card opacity only affects the background, not contents
    readonly property real cardOpacity: parent ? (parent.cardOpacity !== undefined ? parent.cardOpacity : deckConfig.globalOpacity) : deckConfig.globalOpacity

    radius: deckConfig.cardRadius
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b,
                   cardOpacity)
    border.width: cardOpacity > 0.02 ? 1 : 0
    border.color: themeManager.borderColor

    // Clip children to rounded corners
    clip: true

    layer.enabled: cardOpacity > 0.05
    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 2
        radius: 8
        samples: 17
        color: "#40000000"
    }
}
