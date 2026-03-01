import QtQuick 2.15

Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property int horizontalAlignment: Text.AlignLeft
    property real scrollSpeed: 30  // pixels per second
    property real pauseDuration: 2000  // ms to pause at each end

    implicitHeight: label.implicitHeight
    clip: true

    Text {
        id: label
        y: 0
        elide: Text.ElideNone
        maximumLineCount: 1

        // Static alignment when not scrolling
        anchors.verticalCenter: parent.verticalCenter
        x: {
            if (scrollAnim.running) return x  // managed by animation
            if (label.implicitWidth <= root.width) {
                switch (root.horizontalAlignment) {
                    case Text.AlignHCenter: return (root.width - label.implicitWidth) / 2
                    case Text.AlignRight: return root.width - label.implicitWidth
                    default: return 0
                }
            }
            return 0
        }
    }

    // Only scroll when text overflows
    SequentialAnimation {
        id: scrollAnim
        running: label.implicitWidth > root.width && root.visible
        loops: Animation.Infinite

        PauseAnimation { duration: root.pauseDuration }

        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: root.width - label.implicitWidth
            duration: Math.abs(root.width - label.implicitWidth) / root.scrollSpeed * 1000
            easing.type: Easing.Linear
        }

        PauseAnimation { duration: root.pauseDuration }

        NumberAnimation {
            target: label
            property: "x"
            from: root.width - label.implicitWidth
            to: 0
            duration: Math.abs(root.width - label.implicitWidth) / root.scrollSpeed * 1000
            easing.type: Easing.Linear
        }
    }

    // When text changes, restart the animation
    Connections {
        target: label
        function onTextChanged() {
            scrollAnim.restart()
        }
    }
}
