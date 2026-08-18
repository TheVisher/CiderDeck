import QtQuick

Item {
    id: pager
    clip: true

    required property int gridColumns
    required property int gridRows
    required property int gridGap
    required property int gridPadding
    required property real cellWidth
    required property real cellHeight

    readonly property int pageCount: deckConfig.pageCount
    property real contentOffset: -deckConfig.currentPage * width
    property real dragStartOffset: contentOffset
    property bool dragging: false

    function beginSwipe() {
        if (editController.editing || pageCount < 2
                || deckConfig.pageType(deckConfig.currentPage) === "agents")
            return
        settleAnimation.stop()
        dragStartOffset = contentOffset
        dragging = true
    }

    function updateSwipe(deltaX) {
        if (!dragging)
            return

        var desired = dragStartOffset + deltaX
        var minOffset = -(pageCount - 1) * width
        if (desired > 0)
            desired *= 0.18
        else if (desired < minOffset)
            desired = minOffset + (desired - minOffset) * 0.18
        contentOffset = desired
    }

    function endSwipe(deltaX, velocityX) {
        if (!dragging)
            return
        dragging = false

        var target = deckConfig.currentPage
        if (Math.abs(velocityX) > 900 || Math.abs(deltaX) > width * 0.18) {
            if (deltaX < 0)
                target++
            else if (deltaX > 0)
                target--
        }
        goToPage(Math.max(0, Math.min(pageCount - 1, target)))
    }

    function goToPage(index) {
        if (pageCount < 1)
            return
        var target = Math.max(0, Math.min(pageCount - 1, index))
        if (deckConfig.currentPage !== target)
            deckConfig.currentPage = target
        settleAnimation.stop()
        settleAnimation.to = -target * width
        settleAnimation.start()
    }

    onWidthChanged: {
        if (!dragging && !settleAnimation.running)
            contentOffset = -deckConfig.currentPage * width
    }

    Connections {
        target: deckConfig
        function onCurrentPageChanged() {
            if (!pager.dragging && !settleAnimation.running)
                pager.goToPage(deckConfig.currentPage)
        }
        function onPagesChanged() {
            pager.goToPage(Math.min(deckConfig.currentPage, pager.pageCount - 1))
        }
    }

    NumberAnimation {
        id: settleAnimation
        target: pager
        property: "contentOffset"
        duration: 280
        easing.type: Easing.OutCubic
    }

    Row {
        x: pager.contentOffset
        width: pager.width * pager.pageCount
        height: pager.height
        spacing: 0

        Repeater {
            model: pager.pageCount

            delegate: Loader {
                id: pageLoader
                required property int index
                width: pager.width
                height: pager.height
                sourceComponent: deckConfig.pageType(index) === "agents"
                                 ? agentWorkspaceComponent : dashboardComponent

                Component {
                    id: dashboardComponent
                    DashboardPage {
                        pageIndex: pageLoader.index
                        gridColumns: pager.gridColumns
                        gridRows: pager.gridRows
                        gridGap: pager.gridGap
                        gridPadding: pager.gridPadding
                        cellWidth: pager.cellWidth
                        cellHeight: pager.cellHeight
                    }
                }

                Component {
                    id: agentWorkspaceComponent
                    AgentWorkspacePage {}
                }
            }
        }
    }

    // These narrow zones keep page gestures available when tiles fill the screen.
    // The direct evdev bridge injects mouse events, so these deliberately use MouseArea.
    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: leftEdgeArea.pressed ? pager.width : 56
        z: 120

        MouseArea {
            id: leftEdgeArea
            anchors.fill: parent
            enabled: !editController.editing && pager.pageCount > 1
                     && deckConfig.pageType(deckConfig.currentPage) !== "agents"
            preventStealing: true

            property real startX: 0
            property real startTime: 0

            onPressed: (mouse) => {
                startX = mapToItem(pager, mouse.x, mouse.y).x
                startTime = Date.now()
                pager.beginSwipe()
            }
            onPositionChanged: (mouse) => {
                if (pressed) {
                    var pointerX = mapToItem(pager, mouse.x, mouse.y).x
                    pager.updateSwipe(pointerX - startX)
                }
            }
            onReleased: (mouse) => {
                var pointerX = mapToItem(pager, mouse.x, mouse.y).x
                var delta = pointerX - startX
                var elapsed = Math.max(1, Date.now() - startTime)
                pager.endSwipe(delta, delta * 1000 / elapsed)
            }
            onCanceled: {
                pager.endSwipe(0, 0)
            }
        }
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: rightEdgeArea.pressed ? pager.width : 56
        z: 120

        MouseArea {
            id: rightEdgeArea
            anchors.fill: parent
            enabled: !editController.editing && pager.pageCount > 1
                     && deckConfig.pageType(deckConfig.currentPage) !== "agents"
            preventStealing: true

            property real startX: 0
            property real startTime: 0

            onPressed: (mouse) => {
                startX = mapToItem(pager, mouse.x, mouse.y).x
                startTime = Date.now()
                pager.beginSwipe()
            }
            onPositionChanged: (mouse) => {
                if (pressed) {
                    var pointerX = mapToItem(pager, mouse.x, mouse.y).x
                    pager.updateSwipe(pointerX - startX)
                }
            }
            onReleased: (mouse) => {
                var pointerX = mapToItem(pager, mouse.x, mouse.y).x
                var delta = pointerX - startX
                var elapsed = Math.max(1, Date.now() - startTime)
                pager.endSwipe(delta, delta * 1000 / elapsed)
            }
            onCanceled: {
                pager.endSwipe(0, 0)
            }
        }
    }
}
