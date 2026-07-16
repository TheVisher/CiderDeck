import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: card

    readonly property real cardOpacity: parent
        ? (parent.cardOpacity !== undefined ? parent.cardOpacity : deckConfig.globalOpacity)
        : deckConfig.globalOpacity
    readonly property real surfaceOpacity: Math.max(0, Math.min(1, cardOpacity))

    radius: 8
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b,
                   surfaceOpacity)
    border.width: surfaceOpacity > 0.02 ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.10)
    clip: true

    layer.enabled: surfaceOpacity > 0.05
    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 3
        radius: 12
        samples: 25
        color: "#38000000"
    }
}
