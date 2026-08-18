import QtQuick
import QtQuick.Controls

FocusScope {
    id: pane

    property string sessionId: ""
    property string sessionLabel: "No session selected"
    property string sessionProvider: ""
    property string sessionModel: ""
    property string terminalOutput: ""
    property bool paneActive: false
    signal activated()

    function reloadOutput() {
        terminalOutput = sessionId === "" ? "" : agentTerminalService.outputForSession(sessionId)
    }

    function sendNamedKey(keyName) {
        if (sessionId !== "")
            agentTerminalService.sendKey(sessionId, keyName)
    }

    function escapedHtml(value) {
        return value.replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
    }

    function formattedOutput() {
        var lines = terminalOutput.split("\n")
        var html = "<pre style='margin:0; white-space:pre;'>"
        var role = "terminal"
        for (var i = 0; i < lines.length; ++i) {
            var trimmed = lines[i].trim()
            if (trimmed.startsWith("›") || trimmed.startsWith("> "))
                role = "user"
            else if (trimmed.startsWith("•") || trimmed.startsWith("⏺"))
                role = trimmed.indexOf("usage limit") >= 0 ? "notice" : "agent"

            var color = "#e8edf5"
            var weight = "400"
            if (role === "user") {
                color = themeManager.accentColor
                weight = "600"
            } else if (role === "notice") {
                color = themeManager.secondaryTextColor
            } else if (role === "agent") {
                color = "#f4f7fb"
            }
            html += "<span style='color:" + color + ";font-weight:" + weight + "'>"
                    + escapedHtml(lines[i]) + "</span>\n"
            if (trimmed === "")
                role = "terminal"
        }
        return html + "</pre>"
    }

    function resizeTerminal() {
        if (sessionId === "" || terminalScroll.availableWidth <= 0
                || terminalScroll.availableHeight <= 0)
            return
        var columns = Math.floor(terminalScroll.availableWidth
                                 / Math.max(7, terminalText.font.pixelSize * 0.61))
        var rows = Math.floor(terminalScroll.availableHeight
                              / Math.max(12, terminalText.font.pixelSize * 1.35))
        agentTerminalService.resizeSession(sessionId, columns, rows)
    }

    onSessionIdChanged: {
        reloadOutput()
        Qt.callLater(resizeTerminal)
    }

    Connections {
        target: agentTerminalService
        function onSessionOutputChanged(id, output) {
            if (id === pane.sessionId) {
                pane.terminalOutput = output
                if (terminalText.selectedText.length === 0)
                    terminalText.cursorPosition = terminalText.length
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: deckConfig.cardRadius
        color: "#090d13"
        border.width: pane.paneActive ? 2 : 1
        border.color: pane.paneActive ? themeManager.accentColor : themeManager.borderColor

        Rectangle {
            id: titleBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38
            radius: parent.radius
            color: pane.paneActive
                   ? Qt.rgba(themeManager.accentColor.r,
                             themeManager.accentColor.g,
                             themeManager.accentColor.b, 0.14)
                   : Qt.rgba(1, 1, 1, 0.035)

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: pane.sessionId === "" ? themeManager.secondaryTextColor
                                              : themeManager.successColor
            }

            Text {
                id: sessionTitle
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                text: pane.sessionLabel
                color: themeManager.textColor
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: pane.sessionModel !== ""
                anchors.left: sessionTitle.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: modelLabel.implicitWidth + 14
                height: 24
                radius: 6
                color: Qt.rgba(themeManager.accentColor.r,
                               themeManager.accentColor.g,
                               themeManager.accentColor.b, 0.14)

                Text {
                    id: modelLabel
                    anchors.centerIn: parent
                    text: pane.sessionModel
                    color: themeManager.accentColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Text {
                visible: pane.paneActive && pane.sessionId !== ""
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "KEYBOARD ACTIVE"
                color: themeManager.accentColor
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }
        }

        ScrollView {
            id: terminalScroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: composer.top
            anchors.margins: 4
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            TextArea {
                id: terminalText
                width: Math.max(terminalScroll.availableWidth, implicitWidth)
                height: Math.max(terminalScroll.availableHeight, implicitHeight)
                readOnly: true
                selectByMouse: true
                text: pane.sessionId === "" ? "" : pane.formattedOutput()
                textFormat: TextEdit.RichText
                color: "#e8edf5"
                selectionColor: themeManager.accentColor
                selectedTextColor: "white"
                font.family: "monospace"
                font.pixelSize: 14
                font.preferShaping: false
                wrapMode: TextEdit.NoWrap
                padding: 10
                background: null

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: (event) => {
                    if (pane.sessionId === "")
                        return

                    pane.activated()
                    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

                    if (ctrl && event.key === Qt.Key_C && terminalText.selectedText.length > 0) {
                        terminalText.copy()
                    } else if ((ctrl && shift && event.key === Qt.Key_V)
                               || (ctrl && event.key === Qt.Key_V)) {
                        agentTerminalService.pasteClipboard(pane.sessionId)
                    } else if (ctrl && event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                        pane.sendNamedKey("C-" + String.fromCharCode(event.key).toLowerCase())
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        pane.sendNamedKey("Enter")
                    } else if (event.key === Qt.Key_Backspace) {
                        pane.sendNamedKey("BSpace")
                    } else if (event.key === Qt.Key_Delete) {
                        pane.sendNamedKey("DC")
                    } else if (event.key === Qt.Key_Tab) {
                        pane.sendNamedKey(shift ? "BTab" : "Tab")
                    } else if (event.key === Qt.Key_Escape) {
                        pane.sendNamedKey("Escape")
                    } else if (event.key === Qt.Key_Up) {
                        pane.sendNamedKey("Up")
                    } else if (event.key === Qt.Key_Down) {
                        pane.sendNamedKey("Down")
                    } else if (event.key === Qt.Key_Left) {
                        pane.sendNamedKey("Left")
                    } else if (event.key === Qt.Key_Right) {
                        pane.sendNamedKey("Right")
                    } else if (event.key === Qt.Key_PageUp) {
                        pane.sendNamedKey("PageUp")
                    } else if (event.key === Qt.Key_PageDown) {
                        pane.sendNamedKey("PageDown")
                    } else if (!ctrl && event.text !== "") {
                        agentTerminalService.sendText(pane.sessionId, event.text)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.DragThreshold
                    onTapped: {
                        terminalText.forceActiveFocus()
                        pane.activated()
                    }
                }

                onWidthChanged: resizeTimer.restart()
                onHeightChanged: resizeTimer.restart()
            }
        }

        Rectangle {
            id: composer
            visible: pane.sessionId !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            height: 48
            radius: 9
            color: Qt.rgba(1, 1, 1, 0.055)
            border.width: promptInput.activeFocus ? 1 : 0
            border.color: themeManager.accentColor

            function submit() {
                if (pane.sessionId === "")
                    return
                if (promptInput.text.length > 0) {
                    agentTerminalService.submitText(pane.sessionId, promptInput.text)
                    promptInput.clear()
                } else {
                    agentTerminalService.sendKey(pane.sessionId, "Enter")
                }
                pane.activated()
            }

            TextField {
                id: promptInput
                anchors.left: parent.left
                anchors.right: sendButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                placeholderText: pane.sessionProvider === "shell"
                                 ? "Type a command…" : "Message " + pane.sessionLabel + "…"
                color: themeManager.textColor
                placeholderTextColor: themeManager.secondaryTextColor
                font.pixelSize: 15
                selectByMouse: true
                background: null
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: (event) => {
                    if (pane.sessionId === "")
                        return
                    if (event.key === Qt.Key_Up) {
                        pane.sendNamedKey("Up")
                    } else if (event.key === Qt.Key_Down) {
                        pane.sendNamedKey("Down")
                    } else if (event.key === Qt.Key_PageUp) {
                        pane.sendNamedKey("PageUp")
                    } else if (event.key === Qt.Key_PageDown) {
                        pane.sendNamedKey("PageDown")
                    } else if (event.key === Qt.Key_Escape) {
                        pane.sendNamedKey("Escape")
                    } else if (event.key === Qt.Key_Tab) {
                        pane.sendNamedKey((event.modifiers & Qt.ShiftModifier) !== 0 ? "BTab" : "Tab")
                    } else if (promptInput.text.length === 0 && event.key === Qt.Key_Left) {
                        pane.sendNamedKey("Left")
                    } else if (promptInput.text.length === 0 && event.key === Qt.Key_Right) {
                        pane.sendNamedKey("Right")
                    } else {
                        return
                    }
                    pane.activated()
                    event.accepted = true
                }
                onActiveFocusChanged: {
                    if (activeFocus)
                        pane.activated()
                }
                onAccepted: composer.submit()
            }

            Rectangle {
                id: sendButton
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 74
                height: 38
                radius: 8
                color: sendArea.containsMouse
                       ? Qt.lighter(themeManager.accentColor, 1.15)
                       : themeManager.accentColor
                opacity: promptInput.text.length > 0 ? 1 : 0.42

                Text {
                    anchors.centerIn: parent
                    text: "SEND  ↵"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: sendArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: promptInput.text.length > 0
                    onClicked: composer.submit()
                }
            }
        }

        Column {
            visible: pane.sessionId === ""
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ">_"
                color: themeManager.accentColor
                font.family: "monospace"
                font.pixelSize: 38
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Choose a session, or tap + to start one"
                color: themeManager.secondaryTextColor
                font.pixelSize: 15
            }
        }
    }

    Timer {
        id: resizeTimer
        interval: 160
        repeat: false
        onTriggered: pane.resizeTerminal()
    }
}
