import QtQuick

Card {
    id: clockTile

    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    // Settings
    readonly property string timeFormat: settings.timeFormat || "12h"
    readonly property string dateFormat: settings.dateFormat || "ddd, MMM d"
    readonly property bool showSeconds: settings.showSeconds || false
    readonly property bool wantDate: settings.showDate !== false
    readonly property string clockStyle: settings.clockStyle || "classic"
    readonly property string datePosition: settings.datePosition || "below"

    // Shared time properties updated by timer
    property string currentTime: ""
    property string currentDate: ""
    property string currentDayName: ""
    property string currentHour: ""
    property string currentMinute: ""
    property string currentSecond: ""
    property string currentAmPm: ""

    // Classic overflow detection
    readonly property real pad: 12
    readonly property real availH: height - pad * 2
    readonly property real classicTimeH: classicTimeText.implicitHeight
    readonly property real classicDateH: classicDateText.implicitHeight
    readonly property real classicPairH: classicTimeH + 4 + classicDateH
    readonly property bool dateFits: classicPairH <= availH

    function formatTime(date) {
        if (timeFormat === "24h") {
            return showSeconds ? Qt.formatTime(date, "HH:mm:ss") : Qt.formatTime(date, "HH:mm")
        } else {
            return showSeconds ? Qt.formatTime(date, "h:mm:ss AP") : Qt.formatTime(date, "h:mm AP")
        }
    }

    function formatDate(date) {
        return Qt.formatDate(date, dateFormat)
    }

    Timer {
        interval: clockTile.showSeconds ? 1000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clockTile.currentTime = clockTile.formatTime(now)
            clockTile.currentDate = clockTile.formatDate(now)
            clockTile.currentDayName = Qt.formatDate(now, "dddd").toUpperCase()
            var h = now.getHours()
            var m = now.getMinutes()
            var s = now.getSeconds()
            if (clockTile.timeFormat === "12h") {
                clockTile.currentAmPm = h >= 12 ? "PM" : "AM"
                h = h % 12
                if (h === 0) h = 12
            } else {
                clockTile.currentAmPm = ""
            }
            clockTile.currentHour = (h < 10 ? "0" : "") + h
            clockTile.currentMinute = (m < 10 ? "0" : "") + m
            clockTile.currentSecond = (s < 10 ? "0" : "") + s

            // Modern date: "13 FEB 2026" format
            var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
            clockTile.currentDate = clockTile.formatDate(now)
            // Store modern date separately via the property; modern style builds its own
        }
    }

    // ─── Classic Style ───
    Item {
        id: classicRoot
        anchors.fill: parent
        visible: clockTile.clockStyle === "classic"

        // Whether date goes above/below (pair mode) vs corner/edge (independent mode)
        readonly property bool pairMode: clockTile.datePosition === "below" || clockTile.datePosition === "above"
        readonly property bool dateAbove: clockTile.datePosition === "above"
        readonly property bool showDate: clockTile.wantDate && clockTile.dateFits

        // Pair container — used for above/below positions
        Column {
            id: classicPair
            visible: classicRoot.pairMode
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 4

            Text {
                id: classicDateAbove
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: themeManager.secondaryTextColor
                visible: classicRoot.showDate && classicRoot.dateAbove
                text: clockTile.currentDate
                font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.1 * clockTile.contentScale
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
            }

            Text {
                id: classicTimeText
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: themeManager.textColor
                text: clockTile.currentTime
                font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.25 * clockTile.contentScale
                font.weight: Font.DemiBold
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 10
            }

            Text {
                id: classicDateText
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: themeManager.secondaryTextColor
                visible: classicRoot.showDate && !classicRoot.dateAbove
                text: clockTile.currentDate
                font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.1 * clockTile.contentScale
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
            }
        }

        // Independent mode — time centered, date positioned independently
        Text {
            id: classicTimeCentered
            visible: !classicRoot.pairMode
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            color: themeManager.textColor
            text: clockTile.currentTime
            font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.25 * clockTile.contentScale
            font.weight: Font.DemiBold
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
        }

        Text {
            id: classicDateIndependent
            visible: !classicRoot.pairMode && classicRoot.showDate
            text: clockTile.currentDate
            color: themeManager.secondaryTextColor
            font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.1 * clockTile.contentScale
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 8
            width: Math.min(implicitWidth, parent.width - 16)

            // Position based on datePosition
            x: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return 8
                    case "top-right":
                    case "bottom-right":
                        return parent.width - width - 8
                    case "top-center":
                    case "bottom-center":
                    default:
                        return (parent.width - width) / 2
                }
            }
            y: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "top-right":
                    case "top-center":
                        return 8
                    case "bottom-left":
                    case "bottom-right":
                    case "bottom-center":
                    default:
                        return parent.height - height - 8
                }
            }

            horizontalAlignment: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return Text.AlignLeft
                    case "top-right":
                    case "bottom-right":
                        return Text.AlignRight
                    default:
                        return Text.AlignHCenter
                }
            }
        }
    }

    // ─── Modern Style ───
    Item {
        id: modernRoot
        anchors.fill: parent
        visible: clockTile.clockStyle === "modern"

        readonly property bool pairMode: clockTile.datePosition === "below" || clockTile.datePosition === "above"
        readonly property bool dateAbove: clockTile.datePosition === "above"
        readonly property real dateFontSize: Math.min(clockTile.width, clockTile.height) * 0.1 * clockTile.contentScale

        // Compute modern date string (hardcoded uppercase format)
        property string modernDateStr: ""
        Connections {
            target: clockTile
            function onCurrentTimeChanged() {
                var now = new Date()
                var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
                modernRoot.modernDateStr = now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear()
            }
        }
        Component.onCompleted: {
            var now = new Date()
            var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
            modernDateStr = now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear()
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: Math.max(2, parent.height * 0.02)

            // Date above
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: clockTile.wantDate && modernRoot.pairMode && modernRoot.dateAbove
                text: modernRoot.modernDateStr
                color: themeManager.secondaryTextColor
                font.pixelSize: modernRoot.dateFontSize
                font.letterSpacing: 2
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
            }

            Text {
                id: modernDayName
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clockTile.currentDayName
                color: themeManager.textColor
                font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.2 * clockTile.contentScale
                font.weight: Font.Bold
                font.letterSpacing: 3
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 10
            }

            Text {
                id: modernTime
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: themeManager.textColor
                font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.14 * clockTile.contentScale
                font.letterSpacing: 2
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
                text: {
                    var t = clockTile.currentHour + ":" + clockTile.currentMinute
                    if (clockTile.showSeconds) t += ":" + clockTile.currentSecond
                    if (clockTile.currentAmPm) t += " " + clockTile.currentAmPm
                    return "\u2014 " + t + " \u2014"
                }
            }

            // Date below
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: clockTile.wantDate && modernRoot.pairMode && !modernRoot.dateAbove
                text: modernRoot.modernDateStr
                color: themeManager.secondaryTextColor
                font.pixelSize: modernRoot.dateFontSize
                font.letterSpacing: 2
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
            }
        }

        // Independent date for corner/edge positions
        Text {
            visible: clockTile.wantDate && !modernRoot.pairMode
            text: modernRoot.modernDateStr
            color: themeManager.secondaryTextColor
            font.pixelSize: modernRoot.dateFontSize
            font.letterSpacing: 2
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 8
            width: Math.min(implicitWidth, parent.width - 16)

            x: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return 8
                    case "top-right":
                    case "bottom-right":
                        return parent.width - width - 8
                    default:
                        return (parent.width - width) / 2
                }
            }
            y: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "top-right":
                    case "top-center":
                        return 8
                    default:
                        return parent.height - height - 8
                }
            }
            horizontalAlignment: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return Text.AlignLeft
                    case "top-right":
                    case "bottom-right":
                        return Text.AlignRight
                    default:
                        return Text.AlignHCenter
                }
            }
        }
    }

    // ─── Flip Style ───
    Item {
        id: flipRoot
        anchors.fill: parent
        visible: clockTile.clockStyle === "flip"

        readonly property real cardAspect: 0.6
        readonly property int digitCount: clockTile.showSeconds ? 6 : 4
        readonly property int separatorCount: clockTile.showSeconds ? 2 : 1
        readonly property bool showAmPm: clockTile.timeFormat === "12h"

        // Calculate card dimensions to fit the tile, accounting for spacing
        readonly property real availWidth: parent.width - 20
        readonly property real availHeight: parent.height - (showAmPm ? 30 : 12)
        // Total items in the row: digits + separators
        readonly property int itemCount: digitCount + separatorCount
        // Spacing between items (estimated, refined after cardW is known)
        readonly property real estSpacing: Math.max(2, availWidth * 0.012)
        readonly property real totalSpacingW: estSpacing * (itemCount - 1)
        // Each separator takes ~0.35 card widths, each digit takes 1 card width
        readonly property real totalUnits: digitCount + separatorCount * 0.35
        readonly property real cardW: Math.min((availWidth - totalSpacingW) / totalUnits,
                                               availHeight * cardAspect)
        readonly property real cardH: cardW / cardAspect

        Row {
            id: flipRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: flipRoot.showAmPm ? -8 : 0
            spacing: flipRoot.estSpacing

            // Hour digit 1
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentHour.charAt(0) }
            // Hour digit 2
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentHour.charAt(1) }

            // Colon 1
            Loader { sourceComponent: flipColon }

            // Minute digit 1
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentMinute.charAt(0) }
            // Minute digit 2
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentMinute.charAt(1) }

            // Second digits (conditional)
            Loader {
                active: clockTile.showSeconds
                visible: active
                sourceComponent: flipColon
            }
            Loader {
                active: clockTile.showSeconds
                visible: active
                sourceComponent: flipDigit
                property string digit: clockTile.currentSecond.charAt(0)
            }
            Loader {
                active: clockTile.showSeconds
                visible: active
                sourceComponent: flipDigit
                property string digit: clockTile.currentSecond.charAt(1)
            }
        }

        // AM/PM label
        Text {
            id: flipAmPm
            visible: flipRoot.showAmPm
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: flipRow.bottom
            anchors.topMargin: 4
            text: clockTile.currentAmPm
            color: themeManager.secondaryTextColor
            font.pixelSize: flipRoot.cardH * 0.18 * clockTile.contentScale
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }

        // Date — positioned independently for all 8 positions
        // "above"/"below" go centered above/below the flip cards
        // corners/edges go to the tile edges
        Text {
            visible: clockTile.wantDate
            text: clockTile.currentDate
            color: themeManager.secondaryTextColor
            font.pixelSize: Math.min(clockTile.width, clockTile.height) * 0.1 * clockTile.contentScale
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 8
            width: Math.min(implicitWidth, parent.width - 16)

            x: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return 8
                    case "top-right":
                    case "bottom-right":
                        return parent.width - width - 8
                    default:
                        return (parent.width - width) / 2
                }
            }
            y: {
                switch (clockTile.datePosition) {
                    case "above":
                        return flipRow.y - height - 6
                    case "top-left":
                    case "top-right":
                    case "top-center":
                        return 8
                    case "below":
                        // Below AM/PM if visible, otherwise below flip row
                        return (flipRoot.showAmPm ? flipAmPm.y + flipAmPm.height : flipRow.y + flipRow.height) + 6
                    default:
                        return parent.height - height - 8
                }
            }
            horizontalAlignment: {
                switch (clockTile.datePosition) {
                    case "top-left":
                    case "bottom-left":
                        return Text.AlignLeft
                    case "top-right":
                    case "bottom-right":
                        return Text.AlignRight
                    default:
                        return Text.AlignHCenter
                }
            }
        }
    }

    // ─── Flip Digit Card Component (animated split-flap) ───
    Component {
        id: flipDigit

        Item {
            id: dCard
            width: flipRoot.cardW
            height: flipRoot.cardH

            property string targetDigit: parent.digit || "0"
            property string shownDigit: targetDigit
            property real flipPhase: 0  // 0=idle, 0→0.5=top falls, 0.5→1=bottom rises
            readonly property bool isFlipping: flipAnim.running

            readonly property real cardRadius: Math.max(2, flipRoot.cardW * 0.08)
            readonly property color cardBg: Qt.darker(themeManager.backgroundColor, 1.4)
            readonly property color cardBorder: Qt.rgba(themeManager.borderColor.r,
                                                        themeManager.borderColor.g,
                                                        themeManager.borderColor.b, 0.6)
            readonly property real fontSize: flipRoot.cardH * 0.65 * clockTile.contentScale

            onTargetDigitChanged: {
                if (shownDigit !== targetDigit && !flipAnim.running) {
                    flipAnim.start()
                }
            }

            SequentialAnimation {
                id: flipAnim
                // Phase 1: top flap folds down (old digit)
                NumberAnimation {
                    target: dCard; property: "flipPhase"
                    from: 0; to: 0.5; duration: 200
                    easing.type: Easing.InQuad
                }
                // Phase 2: bottom flap unfolds (new digit)
                NumberAnimation {
                    target: dCard; property: "flipPhase"
                    from: 0.5; to: 1.0; duration: 200
                    easing.type: Easing.OutQuad
                }
                // Swap shown digit after flap has fully landed
                ScriptAction { script: dCard.shownDigit = dCard.targetDigit }
                PropertyAction { target: dCard; property: "flipPhase"; value: 0 }
            }

            // ── Static bottom half: shows OLD digit until midpoint, then NEW ──
            Item {
                y: dCard.height / 2
                width: dCard.width; height: dCard.height / 2
                clip: true

                Rectangle {
                    width: dCard.width; height: dCard.height; y: -dCard.height / 2
                    radius: dCard.cardRadius; color: dCard.cardBg

                    Text {
                        anchors.centerIn: parent
                        text: dCard.shownDigit
                        color: themeManager.textColor
                        font.pixelSize: dCard.fontSize; font.weight: Font.Bold; font.family: "monospace"
                    }
                }
            }

            // ── Static top half: shows NEW digit behind the falling flap ──
            Item {
                y: 0; width: dCard.width; height: dCard.height / 2
                clip: true

                Rectangle {
                    width: dCard.width; height: dCard.height
                    radius: dCard.cardRadius; color: dCard.cardBg

                    // Top-half depth gradient
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: parent.height / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        // During animation show NEW digit (revealed behind flap); idle shows current
                        text: dCard.isFlipping ? dCard.targetDigit : dCard.shownDigit
                        color: themeManager.textColor
                        font.pixelSize: dCard.fontSize; font.weight: Font.Bold; font.family: "monospace"
                    }
                }
            }

            // ── Animated top flap: OLD digit folds downward ──
            Item {
                id: topFlap
                y: 0; width: dCard.width; height: dCard.height / 2
                clip: true
                visible: dCard.isFlipping && dCard.flipPhase <= 0.5

                transform: Scale {
                    origin.x: topFlap.width / 2
                    origin.y: topFlap.height  // pivot at bottom edge
                    yScale: 1.0 - dCard.flipPhase * 2  // 1.0 → 0.0
                }

                Rectangle {
                    width: dCard.width; height: dCard.height
                    radius: dCard.cardRadius; color: dCard.cardBg

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: parent.height / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dCard.shownDigit  // still OLD digit during phase 1
                        color: themeManager.textColor
                        font.pixelSize: dCard.fontSize; font.weight: Font.Bold; font.family: "monospace"
                    }
                }
            }

            // ── Animated bottom flap: NEW digit unfolds downward ──
            Item {
                id: bottomFlap
                y: dCard.height / 2; width: dCard.width; height: dCard.height / 2
                clip: true
                visible: dCard.flipPhase > 0.5 && dCard.flipPhase < 1.0

                transform: Scale {
                    origin.x: bottomFlap.width / 2
                    origin.y: 0  // pivot at top edge
                    yScale: (dCard.flipPhase - 0.5) * 2  // 0.0 → 1.0
                }

                Rectangle {
                    width: dCard.width; height: dCard.height; y: -dCard.height / 2
                    radius: dCard.cardRadius; color: dCard.cardBg

                    Text {
                        anchors.centerIn: parent
                        text: dCard.targetDigit
                        color: themeManager.textColor
                        font.pixelSize: dCard.fontSize; font.weight: Font.Bold; font.family: "monospace"
                    }
                }
            }

            // ── Shadow on bottom half while top flap falls (depth cue) ──
            Rectangle {
                y: dCard.height / 2; width: dCard.width; height: dCard.height / 2
                color: Qt.rgba(0, 0, 0, 0.12 * Math.max(0, 1.0 - dCard.flipPhase * 2))
                visible: dCard.flipPhase > 0 && dCard.flipPhase <= 0.5
                z: 5
            }

            // ── Split line ──
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 1; anchors.rightMargin: 1
                y: dCard.height / 2 - 0.5; height: 1
                color: Qt.rgba(0, 0, 0, 0.3); z: 10
            }

            // ── Border overlay ──
            Rectangle {
                anchors.fill: parent; radius: dCard.cardRadius
                color: "transparent"; border.width: 1; border.color: dCard.cardBorder; z: 11
            }
        }
    }

    // ─── Flip Colon Component ───
    Component {
        id: flipColon

        Item {
            width: flipRoot.cardW * 0.35
            height: flipRoot.cardH

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.3 - height / 2
                width: Math.max(3, flipRoot.cardW * 0.12)
                height: width
                radius: width / 2
                color: themeManager.textColor
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.7 - height / 2
                width: Math.max(3, flipRoot.cardW * 0.12)
                height: width
                radius: width / 2
                color: themeManager.textColor
            }
        }
    }
}
