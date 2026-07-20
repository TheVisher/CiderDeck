import QtQuick

Card {
    id: clockTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1.0) : 1.0

    readonly property string timeFormat: settings.timeFormat || "12h"
    readonly property string dateFormat: settings.dateFormat || "ddd, MMM d"
    readonly property bool showSeconds: settings.showSeconds || false
    readonly property bool wantDate: settings.showDate !== false
    readonly property string clockStyle: settings.clockStyle || "classic"
    readonly property string datePosition: settings.datePosition || "below"
    readonly property bool pairDate: datePosition === "below" || datePosition === "above"
    readonly property bool dateAbove: datePosition === "above"

    property string currentDate: ""
    property string currentModernDate: ""
    property string currentDayName: ""
    property string currentHour: ""
    property string currentMinute: ""
    property string currentSecond: ""
    property string currentAmPm: ""

    readonly property string mainTimeText: {
        var hour = currentHour
        if (clockStyle === "classic" && timeFormat === "12h" && hour.charAt(0) === "0")
            hour = hour.substring(1)
        var result = hour + ":" + currentMinute
        if (clockStyle === "modern" && showSeconds)
            result += ":" + currentSecond
        return result
    }
    readonly property string displayedDate: clockStyle === "modern"
                                                    ? currentModernDate : currentDate
    readonly property real baseDimension: Math.min(width, height)
    readonly property real flipBaseCardWidth: Math.max(12, Math.min(
        (width - 64) / (showSeconds ? 7.8 : 4.35),
        (height - 44) * 0.31))

    Timer {
        interval: clockTile.showSeconds ? 1000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var hours = now.getHours()
            var minutes = now.getMinutes()
            var seconds = now.getSeconds()
            clockTile.currentAmPm = ""
            if (clockTile.timeFormat === "12h") {
                clockTile.currentAmPm = hours >= 12 ? "PM" : "AM"
                hours = hours % 12
                if (hours === 0) hours = 12
            }
            clockTile.currentHour = (hours < 10 ? "0" : "") + hours
            clockTile.currentMinute = (minutes < 10 ? "0" : "") + minutes
            clockTile.currentSecond = (seconds < 10 ? "0" : "") + seconds
            clockTile.currentDate = Qt.formatDate(now, clockTile.dateFormat)
            clockTile.currentDayName = Qt.formatDate(now, "dddd").toUpperCase()
            var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            clockTile.currentModernDate = now.getDate() + " "
                                        + months[now.getMonth()] + " " + now.getFullYear()
        }
    }

    Item {
        id: contentCanvas
        anchors.fill: parent
        anchors.margins: 12

        readonly property real itemGap: 10
        readonly property real rowHeight: Math.max(timeItem.height,
                                                    secondsItem.visible ? secondsItem.height : 0,
                                                    periodItem.visible && clockTile.clockStyle !== "flip"
                                                    ? periodItem.height : 0)
        readonly property real rowWidth: timeItem.width
                                           + (secondsItem.visible ? itemGap + secondsItem.width : 0)
                                           + (periodItem.visible && clockTile.clockStyle !== "flip"
                                              ? itemGap + periodItem.width : 0)
        readonly property real pairedDateHeight: dateItem.visible && clockTile.pairDate
                                                  ? itemGap + dateItem.height : 0
        readonly property real modernTotalHeight: (dayItem.visible ? dayItem.height + itemGap : 0)
                                                   + rowHeight + pairedDateHeight
        readonly property real classicTotalHeight: rowHeight + pairedDateHeight
        readonly property real flipPeriodHeight: periodItem.visible
                                                 ? itemGap + periodItem.height : 0
        readonly property real flipTotalHeight: rowHeight + flipPeriodHeight
                                                + pairedDateHeight
        readonly property real modernStartY: Math.max(0, (height - modernTotalHeight) / 2)
        readonly property real classicStartY: Math.max(0, (height - classicTotalHeight) / 2)
        readonly property real flipStartY: Math.max(0, (height - flipTotalHeight) / 2)

        function timeDefaultY() {
            if (clockTile.clockStyle === "modern")
                return modernStartY
                    + (dateItem.visible && clockTile.dateAbove ? dateItem.height + itemGap : 0)
                    + (dayItem.visible ? dayItem.height + itemGap : 0)
            if (clockTile.clockStyle === "flip")
                return flipStartY
                    + (dateItem.visible && clockTile.dateAbove ? dateItem.height + itemGap : 0)
            return classicStartY
                + (dateItem.visible && clockTile.dateAbove ? dateItem.height + itemGap : 0)
        }

        function dateDefaultX() {
            switch (clockTile.datePosition) {
            case "top-left":
            case "bottom-left": return 0
            case "top-right":
            case "bottom-right": return width - dateItem.width
            default: return (width - dateItem.width) / 2
            }
        }

        function dateDefaultY() {
            if (clockTile.pairDate) {
                if (clockTile.dateAbove) {
                    if (clockTile.clockStyle === "modern") return modernStartY
                    if (clockTile.clockStyle === "flip") return flipStartY
                    return classicStartY
                }
                var bottom = timeItem.y + rowHeight
                if (clockTile.clockStyle === "flip" && periodItem.visible)
                    bottom = periodItem.y + periodItem.height
                return bottom + itemGap
            }
            switch (clockTile.datePosition) {
            case "top-left":
            case "top-right":
            case "top-center": return 0
            default: return height - dateItem.height
            }
        }

        Item {
            id: dayItem
            width: dayRow.implicitWidth
            height: dayRow.implicitHeight
            x: contentLayout.hasSavedValue("day", "x")
               ? contentLayout.elementX("day") : (contentCanvas.width - width) / 2
            y: contentLayout.hasSavedValue("day", "y")
               ? contentLayout.elementY("day")
               : contentCanvas.modernStartY
                 + (dateItem.visible && clockTile.dateAbove
                    ? dateItem.height + contentCanvas.itemGap : 0)
            visible: clockTile.clockStyle === "modern" && contentLayout.elementVisible("day")
            z: clockTile.selectedElement === "day" ? 20 : 1
            Row {
                id: dayRow
                spacing: 10 * clockTile.contentScale
                         * contentLayout.elementScale("day")

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(18, clockTile.baseDimension * 0.09)
                           * contentLayout.elementScale("day")
                    height: Math.max(2, 2 * clockTile.contentScale
                                          * contentLayout.elementScale("day"))
                    radius: height / 2
                    color: themeManager.textColor
                    opacity: 0.8
                }

                Text {
                    id: dayVisual
                    anchors.verticalCenter: parent.verticalCenter
                    text: clockTile.currentDayName
                    color: themeManager.textColor
                    font.pixelSize: clockTile.baseDimension * 0.2 * clockTile.contentScale
                                    * contentLayout.elementFontScale("day")
                    font.weight: Font.Bold
                    font.letterSpacing: 3
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(18, clockTile.baseDimension * 0.09)
                           * contentLayout.elementScale("day")
                    height: Math.max(2, 2 * clockTile.contentScale
                                          * contentLayout.elementScale("day"))
                    radius: height / 2
                    color: themeManager.textColor
                    opacity: 0.8
                }
            }
            ContentEditableFrame { host: contentLayout; elementId: "day" }
        }

        Item {
            id: timeItem
            width: timeLoader.implicitWidth
            height: timeLoader.implicitHeight
            x: contentLayout.hasSavedValue("time", "x")
               ? contentLayout.elementX("time")
               : (contentCanvas.width - contentCanvas.rowWidth) / 2
            y: contentLayout.hasSavedValue("time", "y")
               ? contentLayout.elementY("time") : contentCanvas.timeDefaultY()
            visible: contentLayout.elementVisible("time")
            z: clockTile.selectedElement === "time" ? 20 : 1
            Loader {
                id: timeLoader
                sourceComponent: clockTile.clockStyle === "flip" ? flipTimeComponent : timeTextComponent
            }
            ContentEditableFrame { host: contentLayout; elementId: "time" }
        }

        Item {
            id: secondsItem
            width: secondsLoader.implicitWidth
            height: secondsLoader.implicitHeight
            x: contentLayout.hasSavedValue("seconds", "x")
               ? contentLayout.elementX("seconds")
               : timeItem.x + timeItem.width + contentCanvas.itemGap
            y: contentLayout.hasSavedValue("seconds", "y")
               ? contentLayout.elementY("seconds")
               : timeItem.y + timeItem.height - height
            visible: clockTile.showSeconds && clockTile.clockStyle === "classic"
                     && contentLayout.elementVisible("seconds")
            z: clockTile.selectedElement === "seconds" ? 20 : 1
            Loader {
                id: secondsLoader
                sourceComponent: secondsTextComponent
            }
            ContentEditableFrame { host: contentLayout; elementId: "seconds" }
        }

        Item {
            id: periodItem
            width: periodText.implicitWidth
            height: periodText.implicitHeight
            x: contentLayout.hasSavedValue("period", "x")
               ? contentLayout.elementX("period")
               : clockTile.clockStyle === "flip"
                 ? (contentCanvas.width - width) / 2
                 : (secondsItem.visible ? secondsItem.x + secondsItem.width
                                        : timeItem.x + timeItem.width) + contentCanvas.itemGap
            y: contentLayout.hasSavedValue("period", "y")
               ? contentLayout.elementY("period")
               : clockTile.clockStyle === "flip"
                 ? timeItem.y + contentCanvas.rowHeight + contentCanvas.itemGap
                 : timeItem.y + timeItem.height - height
            visible: clockTile.timeFormat === "12h" && contentLayout.elementVisible("period")
            z: clockTile.selectedElement === "period" ? 20 : 1
            Text {
                id: periodText
                text: clockTile.currentAmPm
                color: themeManager.secondaryTextColor
                font.pixelSize: (clockTile.clockStyle === "flip"
                                 ? clockTile.flipBaseCardWidth / 0.6 * 0.18
                                 : clockTile.baseDimension * 0.075)
                                * clockTile.contentScale
                                * contentLayout.elementFontScale("period")
                font.weight: Font.DemiBold
                font.letterSpacing: clockTile.clockStyle === "modern" ? 2 : 1
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "period" }
        }

        Item {
            id: dateItem
            width: dateText.implicitWidth
            height: dateText.implicitHeight
            x: contentLayout.hasSavedValue("date", "x")
               ? contentLayout.elementX("date") : contentCanvas.dateDefaultX()
            y: contentLayout.hasSavedValue("date", "y")
               ? contentLayout.elementY("date") : contentCanvas.dateDefaultY()
            visible: clockTile.wantDate && contentLayout.elementVisible("date")
            z: clockTile.selectedElement === "date" ? 20 : 1
            Text {
                id: dateText
                text: clockTile.displayedDate
                color: themeManager.secondaryTextColor
                font.pixelSize: clockTile.baseDimension * 0.1 * clockTile.contentScale
                                * contentLayout.elementFontScale("date")
                font.letterSpacing: clockTile.clockStyle === "modern" ? 2 : 0
                renderType: Text.NativeRendering
            }
            ContentEditableFrame { host: contentLayout; elementId: "date" }
        }
    }

    Component {
        id: timeTextComponent
        Text {
            text: clockTile.mainTimeText
            color: themeManager.textColor
            font.pixelSize: clockTile.baseDimension
                            * (clockTile.clockStyle === "modern" ? 0.14 : 0.25)
                            * clockTile.contentScale
                            * contentLayout.elementFontScale("time")
            font.weight: clockTile.clockStyle === "classic" ? Font.DemiBold : Font.Normal
            font.letterSpacing: clockTile.clockStyle === "modern" ? 2 : 0
            renderType: Text.NativeRendering
        }
    }

    Component {
        id: secondsTextComponent
        Text {
            text: ":" + clockTile.currentSecond
            color: themeManager.textColor
            font.pixelSize: clockTile.baseDimension
                            * (clockTile.clockStyle === "modern" ? 0.14 : 0.18)
                            * clockTile.contentScale
                            * contentLayout.elementFontScale("seconds")
            font.weight: clockTile.clockStyle === "classic" ? Font.DemiBold : Font.Normal
            font.letterSpacing: clockTile.clockStyle === "modern" ? 2 : 0
            renderType: Text.NativeRendering
        }
    }

    Component {
        id: flipTimeComponent
        Row {
            spacing: Math.max(2, clockTile.flipBaseCardWidth * 0.08)
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentHour.charAt(0); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentHour.charAt(1); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
            Loader { sourceComponent: flipColon; property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time") }
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentMinute.charAt(0); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
            Loader { sourceComponent: flipDigit; property string digit: clockTile.currentMinute.charAt(1); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
            Loader { active: clockTile.showSeconds; visible: active; sourceComponent: flipColon; property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time") }
            Loader { active: clockTile.showSeconds; visible: active; sourceComponent: flipDigit; property string digit: clockTile.currentSecond.charAt(0); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
            Loader { active: clockTile.showSeconds; visible: active; sourceComponent: flipDigit; property string digit: clockTile.currentSecond.charAt(1); property real cardWidth: clockTile.flipBaseCardWidth * contentLayout.elementScale("time"); property real digitScale: contentLayout.elementTextScale("time") }
        }
    }

    Component {
        id: flipDigit
        Item {
            id: digitCard
            width: parent.cardWidth
            height: width / 0.6
            property string targetDigit: parent.digit || "0"
            property string shownDigit: targetDigit
            property real flipPhase: 0
            readonly property bool isFlipping: flipAnimation.running
            readonly property real cardRadius: Math.max(2, width * 0.08)
            readonly property color cardBackground: Qt.darker(themeManager.backgroundColor, 1.4)
            readonly property real digitFontSize: height * 0.65 * clockTile.contentScale
                                                       * (parent.digitScale || 1)

            onTargetDigitChanged: {
                if (shownDigit !== targetDigit && !flipAnimation.running)
                    flipAnimation.start()
            }
            SequentialAnimation {
                id: flipAnimation
                NumberAnimation { target: digitCard; property: "flipPhase"; from: 0; to: 0.5; duration: 200; easing.type: Easing.InQuad }
                NumberAnimation { target: digitCard; property: "flipPhase"; from: 0.5; to: 1; duration: 200; easing.type: Easing.OutQuad }
                ScriptAction { script: digitCard.shownDigit = digitCard.targetDigit }
                PropertyAction { target: digitCard; property: "flipPhase"; value: 0 }
            }

            Item {
                y: digitCard.height / 2; width: digitCard.width; height: digitCard.height / 2; clip: true
                Rectangle {
                    width: digitCard.width; height: digitCard.height; y: -digitCard.height / 2
                    radius: digitCard.cardRadius; color: digitCard.cardBackground
                    Text { anchors.centerIn: parent; text: digitCard.shownDigit; color: themeManager.textColor; font.pixelSize: digitCard.digitFontSize; font.weight: Font.Bold; font.family: "monospace"; renderType: Text.NativeRendering }
                }
            }
            Item {
                width: digitCard.width; height: digitCard.height / 2; clip: true
                Rectangle {
                    width: digitCard.width; height: digitCard.height
                    radius: digitCard.cardRadius; color: digitCard.cardBackground
                    Text { anchors.centerIn: parent; text: digitCard.isFlipping ? digitCard.targetDigit : digitCard.shownDigit; color: themeManager.textColor; font.pixelSize: digitCard.digitFontSize; font.weight: Font.Bold; font.family: "monospace"; renderType: Text.NativeRendering }
                }
            }
            Item {
                id: topFlap
                width: digitCard.width; height: digitCard.height / 2; clip: true
                visible: digitCard.isFlipping && digitCard.flipPhase <= 0.5
                transform: Scale { origin.x: topFlap.width / 2; origin.y: topFlap.height; yScale: 1 - digitCard.flipPhase * 2 }
                Rectangle {
                    width: digitCard.width; height: digitCard.height
                    radius: digitCard.cardRadius; color: digitCard.cardBackground
                    Text { anchors.centerIn: parent; text: digitCard.shownDigit; color: themeManager.textColor; font.pixelSize: digitCard.digitFontSize; font.weight: Font.Bold; font.family: "monospace"; renderType: Text.NativeRendering }
                }
            }
            Item {
                id: bottomFlap
                y: digitCard.height / 2; width: digitCard.width; height: digitCard.height / 2; clip: true
                visible: digitCard.flipPhase > 0.5 && digitCard.flipPhase < 1
                transform: Scale { origin.x: bottomFlap.width / 2; origin.y: 0; yScale: (digitCard.flipPhase - 0.5) * 2 }
                Rectangle {
                    width: digitCard.width; height: digitCard.height; y: -digitCard.height / 2
                    radius: digitCard.cardRadius; color: digitCard.cardBackground
                    Text { anchors.centerIn: parent; text: digitCard.targetDigit; color: themeManager.textColor; font.pixelSize: digitCard.digitFontSize; font.weight: Font.Bold; font.family: "monospace"; renderType: Text.NativeRendering }
                }
            }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; y: parent.height / 2 - 0.5; height: 1; color: Qt.rgba(0, 0, 0, 0.3); z: 10 }
            Rectangle { anchors.fill: parent; radius: digitCard.cardRadius; color: "transparent"; border.width: 1; border.color: themeManager.borderColor; z: 11 }
        }
    }

    Component {
        id: flipColon
        Item {
            width: parent.cardWidth * 0.35
            height: parent.cardWidth / 0.6
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.3 - height / 2; width: Math.max(3, parent.parent.cardWidth * 0.12); height: width; radius: width / 2; color: themeManager.textColor }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.7 - height / 2; width: Math.max(3, parent.parent.cardWidth * 0.12); height: width; radius: width / 2; color: themeManager.textColor }
        }
    }

    ContentLayoutController {
        id: contentLayout
        tile: clockTile; canvas: contentCanvas; tileId: clockTile.tileId
        settings: clockTile.settings; contentEditMode: clockTile.contentEditMode
        selectedElement: clockTile.selectedElement; contentScale: clockTile.contentScale
        elements: [
            { id: "time", label: "Time", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "seconds", label: "Seconds", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "period", label: "AM / PM", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "date", label: "Date", scale: 1, textScale: 1, visible: true, hasText: true },
            { id: "day", label: "Day (Modern)", scale: 1, textScale: 1, visible: true, hasText: true }
        ]
        itemForId: function(elementId) {
            if (elementId === "time") return timeItem
            if (elementId === "seconds") return secondsItem
            if (elementId === "period") return periodItem
            if (elementId === "date") return dateItem
            if (elementId === "day") return dayItem
            return null
        }
    }
}
