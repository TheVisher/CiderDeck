import QtQuick

Item {
    id: slider

    signal valueRequested(real value)
    signal iconClicked()

    property real value: 0
    property string label: ""
    property string detail: ""
    property alias iconSource: controlIcon.source
    property color accentColor: themeManager.accentColor
    property bool muted: false
    property bool available: true
    property real contentScale: 1
    property real sliderThickness: 3
    property real knobSize: 1
    property string knobShape: "pill"
    property color knobColor: "#f5f7fa"
    property color iconColor: effectiveAccent
    property color valueColor: themeManager.textColor
    property bool showIcon: true
    property bool showValue: true

    readonly property real clampedValue: Math.max(0, Math.min(1, value))
    readonly property color effectiveAccent: muted ? themeManager.secondaryTextColor : accentColor
    readonly property real trackWidth: 8 * sliderThickness
    readonly property real knobBase: trackWidth + 12 * knobSize
    readonly property real knobCross: knobShape === "square" ? knobBase * 0.85 : knobBase
    readonly property real knobAlong: knobShape === "circle" ? knobBase
        : knobShape === "square" ? knobBase * 0.85
        : Math.max(knobBase * 0.55, 8)
    readonly property real knobRadius: knobShape === "circle" ? knobBase / 2
        : knobShape === "square" ? 3
        : knobAlong / 2

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Text {
            width: parent.width
            text: slider.label.toUpperCase()
            color: themeManager.secondaryTextColor
            font.pixelSize: 11 * slider.contentScale
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Rectangle {
            id: iconButton
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46 * slider.contentScale
            height: slider.showIcon ? width : 0
            visible: slider.showIcon
            radius: 8
            color: iconArea.pressed
                   ? Qt.rgba(1, 1, 1, 0.15)
                   : Qt.rgba(1, 1, 1, 0.065)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)

            LucideIcon {
                id: controlIcon
                anchors.centerIn: parent
                width: 21 * slider.contentScale
                height: width
                color: slider.muted ? themeManager.secondaryTextColor : slider.iconColor
            }

            MouseArea {
                id: iconArea
                anchors.fill: parent
                enabled: slider.available
                onClicked: slider.iconClicked()
            }
        }

        Item {
            id: sliderArea
            width: parent.width
            height: parent.height
                    - parent.spacing * 4
                    - parent.children[0].height
                    - iconButton.height
                    - valueText.height
                    - detailText.height
            opacity: slider.available ? 1 : 0.3

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: slider.trackWidth
                height: parent.height
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    height: Math.max(0, (parent.height - 8) * slider.clampedValue)
                    radius: 5
                    color: slider.effectiveAccent

                    Behavior on height {
                        enabled: !dragArea.pressed
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    width: slider.knobCross
                    height: slider.knobAlong
                    radius: slider.knobRadius
                    color: slider.knobColor
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.24)
                    x: (parent.width - width) / 2
                    y: Math.max(0, Math.min(parent.height - height,
                        (parent.height - height) * (1 - slider.clampedValue)))
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                preventStealing: true
                enabled: slider.available

                function updateValue(mouse) {
                    var localY = mapToItem(track, mouse.x, mouse.y).y
                    slider.valueRequested(Math.max(0, Math.min(1, 1 - localY / track.height)))
                }

                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse) }
            }
        }

        Text {
            id: valueText
            width: parent.width
            height: slider.showValue ? implicitHeight : 0
            visible: slider.showValue
            text: Math.round(slider.clampedValue * 100) + "%"
            color: slider.muted ? themeManager.secondaryTextColor : slider.valueColor
            font.pixelSize: 18 * slider.contentScale
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: detailText
            width: parent.width
            height: text === "" ? 0 : implicitHeight
            text: slider.available ? slider.detail : "Unavailable"
            color: slider.available ? themeManager.secondaryTextColor : themeManager.errorColor
            font.pixelSize: 9 * slider.contentScale
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
        }
    }
}
