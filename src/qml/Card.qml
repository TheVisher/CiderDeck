import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: card

    radius: deckConfig.cardRadius
    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b,
                   deckConfig.globalOpacity)
    border.width: 1
    border.color: themeManager.borderColor

    layer.enabled: true
    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 2
        radius: 8
        samples: 17
        color: "#40000000"
    }
}
