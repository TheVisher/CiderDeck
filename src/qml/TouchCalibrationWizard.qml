import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: touchCalibrationWizard

    readonly property var targets: [
        Qt.point(0.1, 0.1), Qt.point(0.9, 0.1), Qt.point(0.9, 0.9),
        Qt.point(0.1, 0.9), Qt.point(0.5, 0.5)
    ]
    readonly property bool collecting: touchCalibrationService.stageName === "collecting"
    readonly property bool previewing: touchCalibrationService.stageName === "preview"
    readonly property bool failed: touchCalibrationService.stageName === "error"

    visible: touchCalibrationService.active
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose

    function cancelCalibration() {
        touchCalibrationService.cancel()
    }

    function activateControlKey(event, control) {
        if (event.key === Qt.Key_Escape) {
            touchCalibrationWizard.cancelCalibration()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            control.activate()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.018, 0.025, 0.038, 0.97)
    }

    Shortcut {
        sequence: "Esc"
        enabled: touchCalibrationWizard.visible
        context: Qt.WindowShortcut
        onActivated: touchCalibrationWizard.cancelCalibration()
    }

    Repeater {
        model: 5

        delegate: Rectangle {
            required property int index
            readonly property bool acknowledged:
                index < touchCalibrationService.acknowledgedPointCount
            readonly property bool current:
                touchCalibrationWizard.collecting && index === touchCalibrationService.currentPoint
            readonly property point normalizedPoint: current
                ? touchCalibrationService.targetPoint : touchCalibrationWizard.targets[index]

            x: normalizedPoint.x * touchCalibrationWizard.width - width / 2
            y: normalizedPoint.y * touchCalibrationWizard.height - height / 2
            width: current ? 80 : 42
            height: width
            radius: width / 2
            color: acknowledged
                ? Qt.rgba(themeManager.successColor.r, themeManager.successColor.g,
                          themeManager.successColor.b, 0.28)
                : current
                  ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                            themeManager.accentColor.b, 0.3)
                  : Qt.rgba(1, 1, 1, 0.04)
            border.width: current ? 4 : 2
            border.color: acknowledged ? themeManager.successColor
                                        : current ? themeManager.accentColor
                                                  : themeManager.borderColor
            visible: touchCalibrationWizard.collecting

            LucideIcon {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "qrc:/icons/lucide/check.svg"
                color: themeManager.successColor
                visible: parent.acknowledged
            }

            Text {
                anchors.centerIn: parent
                text: parent.index + 1
                color: themeManager.textColor
                font.pixelSize: parent.current ? 24 : 14
                font.bold: parent.current
                visible: !parent.acknowledged
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(10, Math.min(64,
                    10 + touchCalibrationService.contactSampleCount * 4))
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: themeManager.textColor
                visible: parent.current && touchCalibrationService.contactSampleCount > 0
            }
        }
    }

    Rectangle {
        id: previewMarker
        x: touchCalibrationService.previewPosition.x * touchCalibrationWizard.width - width / 2
        y: touchCalibrationService.previewPosition.y * touchCalibrationWizard.height - height / 2
        width: 58
        height: 58
        radius: 29
        color: Qt.rgba(themeManager.successColor.r, themeManager.successColor.g,
                       themeManager.successColor.b, 0.24)
        border.width: 4
        border.color: themeManager.successColor
        visible: touchCalibrationWizard.previewing

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: themeManager.textColor
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 18
        width: Math.min(parent.width - 260, 1040)
        height: 72
        radius: 14
        color: Qt.rgba(themeManager.backgroundColor.r, themeManager.backgroundColor.g,
                       themeManager.backgroundColor.b, 0.94)
        border.width: 1
        border.color: failed || touchCalibrationService.errorMessage.length > 0
            ? themeManager.errorColor : themeManager.borderColor

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: touchCalibrationWizard.collecting
                    ? "Touch and briefly hold point " + (touchCalibrationService.currentPoint + 1) + " of 5"
                    : touchCalibrationWizard.previewing
                      ? "Calibration preview"
                      : "Calibration needs another pass"
                color: touchCalibrationWizard.failed ? themeManager.errorColor
                                                     : themeManager.textColor
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: touchCalibrationWizard.collecting
                    ? "Hold steady while samples are averaged. Completed points remain checked."
                    : touchCalibrationWizard.previewing
                      ? (touchCalibrationService.errorMessage.length > 0
                         ? touchCalibrationService.errorMessage
                         : "Touch around the display. The green marker should follow your finger.")
                      : touchCalibrationService.errorMessage
                color: touchCalibrationService.errorMessage.length > 0
                    ? themeManager.errorColor : themeManager.secondaryTextColor
                font.pixelSize: 14
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 960)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        spacing: 12

        Button {
            id: retryPointButton
            text: "Redo previous point"
            visible: touchCalibrationWizard.collecting
                     && touchCalibrationService.acknowledgedPointCount > 0
            enabled: visible
            implicitWidth: 190
            implicitHeight: 48
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Redo previous calibration point"
            Accessible.onPressAction: retryPointButton.activate()
            Keys.onPressed: (event) => touchCalibrationWizard.activateControlKey(event, retryPointButton)

            function activate() {
                if (enabled)
                    touchCalibrationService.retry()
            }

            onClicked: retryPointButton.activate()
        }

        Button {
            id: cancelCalibrationButton
            focus: true
            text: "Cancel"
            implicitWidth: 132
            implicitHeight: 48
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Cancel calibration and restore the previous mapping"
            Accessible.onPressAction: cancelCalibrationButton.activate()
            Keys.onPressed: (event) => touchCalibrationWizard.activateControlKey(event, cancelCalibrationButton)

            function activate() {
                touchCalibrationWizard.cancelCalibration()
            }

            onClicked: cancelCalibrationButton.activate()
        }

        Button {
            id: retryCalibrationButton
            text: "Retry all points"
            visible: touchCalibrationWizard.failed
            enabled: visible
            implicitWidth: 168
            implicitHeight: 48
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Retry all five calibration points"
            Accessible.onPressAction: retryCalibrationButton.activate()
            Keys.onPressed: (event) => touchCalibrationWizard.activateControlKey(event, retryCalibrationButton)

            function activate() {
                if (enabled)
                    touchCalibrationService.retry()
            }

            onClicked: retryCalibrationButton.activate()
        }

        Button {
            id: applyCalibrationButton
            text: "Apply calibration"
            visible: touchCalibrationWizard.previewing
            enabled: touchCalibrationService.canApply
            implicitWidth: 172
            implicitHeight: 48
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Apply the previewed touchscreen calibration"
            Accessible.onPressAction: applyCalibrationButton.activate()
            Keys.onPressed: (event) => touchCalibrationWizard.activateControlKey(event, applyCalibrationButton)

            function activate() {
                if (enabled)
                    touchCalibrationService.apply()
            }

            onClicked: applyCalibrationButton.activate()
        }
    }
}
