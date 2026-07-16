import QtQuick

Item {
    id: pageNav

    property int pageCount: 1
    property int currentPage: 0
    property bool editMode: editController ? editController.editing : false
    signal pageRequested(int index)
    signal swipeStarted()
    signal swipeUpdated(real deltaX)
    signal swipeFinished(real deltaX, real velocityX)

    visible: pageCount > 1

    // Full-width strip, 40px tall
    implicitWidth: parent ? parent.width : 400
    implicitHeight: 40

    // Dragging anywhere on this strip directly moves the horizontal page track.
    MouseArea {
        id: swipeArea
        anchors.fill: parent
        enabled: !pageNav.editMode
        preventStealing: true

        property real startX: 0
        property real startTime: 0

        onPressed: (mouse) => {
            startX = mouse.x
            startTime = Date.now()
            pageNav.swipeStarted()
        }
        onPositionChanged: (mouse) => {
            if (pressed)
                pageNav.swipeUpdated(mouse.x - startX)
        }
        onReleased: (mouse) => {
            var delta = mouse.x - startX
            var elapsed = Math.max(1, Date.now() - startTime)
            pageNav.swipeFinished(delta, delta * 1000 / elapsed)
        }
        onCanceled: {
            pageNav.swipeFinished(0, 0)
        }
    }

    // ─── Left arrow ───
    Rectangle {
        id: leftArrow
        visible: !pageNav.editMode
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: leftArrowArea.containsMouse ? themeManager.overlayColor : "transparent"
        opacity: pageNav.currentPage > 0 ? 1.0 : 0.2

        LucideIcon {
            anchors.centerIn: parent
            width: 16; height: 16
            source: "qrc:/icons/lucide/chevron-left.svg"
            color: themeManager.textColor
        }

        MouseArea {
            id: leftArrowArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: pageNav.currentPage > 0
            onClicked: pageNav.pageRequested(pageNav.currentPage - 1)
        }
    }

    // ─── Right arrow ───
    Rectangle {
        id: rightArrow
        visible: !pageNav.editMode
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: rightArrowArea.containsMouse ? themeManager.overlayColor : "transparent"
        opacity: pageNav.currentPage < pageNav.pageCount - 1 ? 1.0 : 0.2

        LucideIcon {
            anchors.centerIn: parent
            width: 16; height: 16
            source: "qrc:/icons/lucide/chevron-right.svg"
            color: themeManager.textColor
        }

        MouseArea {
            id: rightArrowArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: pageNav.currentPage < pageNav.pageCount - 1
            onClicked: pageNav.pageRequested(pageNav.currentPage + 1)
        }
    }

    // ─── Center dots ───
    Row {
        id: dotsRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: pageNav.pageCount

            delegate: Rectangle {
                required property int index

                width: index === pageNav.currentPage ? 20 : 8
                height: 8
                radius: 4
                color: index === pageNav.currentPage
                       ? themeManager.accentColor
                       : themeManager.secondaryTextColor
                opacity: index === pageNav.currentPage ? 1.0 : 0.4

                Behavior on width { NumberAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6  // bigger hit target
                    onClicked: pageNav.pageRequested(index)
                }
            }
        }
    }
}
