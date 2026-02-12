import QtQuick

Row {
    id: pageDots

    property int pageCount: 1
    property int currentPage: 0

    spacing: 8
    visible: pageCount > 1

    Repeater {
        model: pageDots.pageCount

        delegate: Rectangle {
            required property int index

            width: index === pageDots.currentPage ? 20 : 8
            height: 8
            radius: 4
            color: index === pageDots.currentPage
                   ? themeManager.accentColor
                   : themeManager.secondaryTextColor
            opacity: index === pageDots.currentPage ? 1.0 : 0.4

            Behavior on width { NumberAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                onClicked: deckConfig.currentPage = index
            }
        }
    }
}
