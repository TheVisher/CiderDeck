import QtQuick
import QtQuick.Controls

Rectangle {
    id: sidebar

    property string selectedSessionId: ""
    property string sideLabel: "LEFT"
    property bool workspaceHeader: false
    property bool splitView: false
    property string editingProjectId: ""
    property string childMenuProjectId: ""

    signal sessionSelected(string sessionId)
    signal splitViewRequested(bool enabled)

    color: Qt.rgba(themeManager.backgroundColor.r,
                   themeManager.backgroundColor.g,
                   themeManager.backgroundColor.b, 0.92)
    border.width: 1
    border.color: themeManager.borderColor
    radius: deckConfig.cardRadius
    clip: true

    function addSession(projectId, provider) {
        var id = agentTerminalService.createSessionForProject(projectId, provider)
        if (id !== "")
            sessionSelected(id)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Item {
            id: sidebarHeader
            width: parent.width
            height: sidebar.workspaceHeader ? 52 : 28

            Row {
                visible: !sidebar.workspaceHeader
                anchors.fill: parent
                Text {
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: sidebar.sideLabel + " SESSIONS"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.1
                }
                Rectangle {
                    width: 28; height: 24; radius: 6
                    color: themeManager.overlayColor
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: agentTerminalService.available ? themeManager.successColor
                                                              : themeManager.errorColor
                    }
                }
            }

            Rectangle {
                id: workspaceIcon
                visible: sidebar.workspaceHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 42; height: 42; radius: 9
                color: iconArea.containsMouse || layoutMenu.opened
                       ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                                 themeManager.accentColor.b, 0.28)
                       : Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                                 themeManager.accentColor.b, 0.16)
                border.width: layoutMenu.opened ? 1 : 0
                border.color: themeManager.accentColor
                Text {
                    anchors.centerIn: parent
                    text: ">_"
                    color: themeManager.accentColor
                    font.family: "monospace"
                    font.pixelSize: 15
                    font.bold: true
                }
                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: layoutMenu.opened ? layoutMenu.close() : layoutMenu.open()
                }
            }

            Column {
                visible: sidebar.workspaceHeader
                anchors.left: workspaceIcon.right
                anchors.leftMargin: 9
                anchors.right: addProjectButton.left
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: parent.width
                    text: "Agent Workspace"
                    color: themeManager.textColor
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: sidebar.splitView ? "Two-pane layout" : "One-pane layout"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: addProjectButton
                visible: sidebar.workspaceHeader
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 8
                color: addProjectArea.containsMouse ? themeManager.overlayColor : "transparent"
                border.width: 1
                border.color: themeManager.borderColor
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: themeManager.textColor
                    font.pixelSize: 22
                }
                MouseArea {
                    id: addProjectArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: agentTerminalService.createProject()
                }
            }
        }

        Flickable {
            width: parent.width
            height: parent.height - y
            contentHeight: projectColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: projectColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: agentTerminalService.projects

                    delegate: Column {
                        id: projectGroup
                        required property var modelData
                        width: projectColumn.width
                        spacing: 4

                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 8
                            color: themeManager.overlayColor
                            border.width: 1
                            border.color: themeManager.borderColor

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8; radius: 4
                                color: themeManager.accentColor
                            }

                            Text {
                                visible: sidebar.editingProjectId !== projectGroup.modelData.id
                                anchors.left: parent.left
                                anchors.leftMargin: 27
                                anchors.right: editButton.left
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾  " + projectGroup.modelData.name
                                color: themeManager.textColor
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            TextField {
                                id: renameField
                                visible: sidebar.editingProjectId === projectGroup.modelData.id
                                anchors.left: parent.left
                                anchors.leftMargin: 24
                                anchors.right: editButton.left
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                height: 38
                                text: projectGroup.modelData.name
                                color: themeManager.textColor
                                font.pixelSize: 13
                                selectByMouse: true
                                onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                                onAccepted: {
                                    agentTerminalService.renameProject(projectGroup.modelData.id, text)
                                    sidebar.editingProjectId = ""
                                }
                            }

                            Rectangle {
                                id: editButton
                                anchors.right: childButton.left
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 36; radius: 7
                                color: editArea.containsMouse ? themeManager.overlayColor : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✎"
                                    color: themeManager.secondaryTextColor
                                    font.pixelSize: 15
                                }
                                MouseArea {
                                    id: editArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: sidebar.editingProjectId = projectGroup.modelData.id
                                }
                            }

                            Rectangle {
                                id: childButton
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38; height: 38; radius: 8
                                color: childArea.containsMouse
                                       ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                                                 themeManager.accentColor.b, 0.25)
                                       : themeManager.overlayColor
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: themeManager.textColor
                                    font.pixelSize: 23
                                }
                                MouseArea {
                                    id: childArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        sidebar.childMenuProjectId = projectGroup.modelData.id
                                        childMenu.open()
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: agentTerminalService.sessions
                            delegate: Rectangle {
                                id: sessionRow
                                required property var modelData
                                readonly property bool belongsHere:
                                    modelData.projectId === projectGroup.modelData.id
                                visible: belongsHere
                                width: projectGroup.width
                                height: visible ? 46 : 0
                                radius: 8
                                color: sidebar.selectedSessionId === modelData.id
                                       ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                                                 themeManager.accentColor.b, 0.22)
                                       : sessionArea.containsMouse ? themeManager.overlayColor : "transparent"
                                border.width: sidebar.selectedSessionId === modelData.id ? 1 : 0
                                border.color: themeManager.accentColor

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18; height: 18; radius: 5
                                    color: modelData.provider === "codex" ? "#244e76"
                                         : modelData.provider === "claude" ? "#754b35" : "#285f50"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.provider === "codex" ? "C"
                                            : modelData.provider === "claude" ? "A" : ">_"
                                        color: "white"
                                        font.pixelSize: modelData.provider === "shell" ? 7 : 10
                                        font.bold: true
                                    }
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 35
                                    anchors.right: closeButton.left
                                    anchors.rightMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: themeManager.textColor
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    id: closeButton
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 34; height: 34; radius: 7
                                    color: closeArea.containsMouse
                                           ? Qt.rgba(themeManager.errorColor.r, themeManager.errorColor.g,
                                                     themeManager.errorColor.b, 0.25) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: themeManager.secondaryTextColor
                                        font.pixelSize: 18
                                    }
                                    MouseArea {
                                        id: closeArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: agentTerminalService.stopSession(sessionRow.modelData.id)
                                    }
                                }
                                MouseArea {
                                    id: sessionArea
                                    anchors.left: parent.left
                                    anchors.right: closeButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    hoverEnabled: true
                                    onClicked: sidebar.sessionSelected(sessionRow.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: childMenu
        x: 6; y: 116
        width: Math.max(196, sidebar.width - 12)
        height: 118
        padding: 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 10
            color: Qt.rgba(themeManager.backgroundColor.r, themeManager.backgroundColor.g,
                           themeManager.backgroundColor.b, 0.98)
            border.width: 1; border.color: themeManager.accentColor
        }
        contentItem: Column {
            spacing: 6
            Text {
                text: "NEW PROJECT TERMINAL"
                color: themeManager.secondaryTextColor
                font.pixelSize: 10; font.bold: true
            }
            Row {
                width: parent.width; height: 72; spacing: 5
                Repeater {
                    model: [
                        { key: "codex", label: "CODEX" },
                        { key: "claude", label: "CLAUDE" },
                        { key: "shell", label: "SHELL" }
                    ]
                    delegate: Rectangle {
                        id: providerChoice
                        required property var modelData
                        width: (parent.width - parent.spacing * 2) / 3
                        height: parent.height
                        radius: 8
                        color: providerArea.containsMouse ? themeManager.overlayColor : "transparent"
                        border.width: 1; border.color: themeManager.borderColor
                        Text {
                            anchors.centerIn: parent
                            text: providerChoice.modelData.label
                            color: themeManager.textColor
                            font.pixelSize: 10; font.bold: true
                        }
                        MouseArea {
                            id: providerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                sidebar.addSession(sidebar.childMenuProjectId,
                                                   providerChoice.modelData.key)
                                childMenu.close()
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: layoutMenu
        x: 6; y: 62
        width: Math.max(196, sidebar.width - 12)
        height: 112
        padding: 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 10
            color: Qt.rgba(themeManager.backgroundColor.r, themeManager.backgroundColor.g,
                           themeManager.backgroundColor.b, 0.98)
            border.width: 1; border.color: themeManager.accentColor
        }
        contentItem: Column {
            spacing: 6
            Text {
                text: "WORKSPACE LAYOUT"
                color: themeManager.secondaryTextColor
                font.pixelSize: 10; font.bold: true
            }
            Row {
                width: parent.width; height: 70; spacing: 6
                Repeater {
                    model: [{ label: "ONE PANE", split: false },
                            { label: "TWO PANES", split: true }]
                    delegate: Rectangle {
                        id: layoutChoice
                        required property var modelData
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        radius: 8
                        color: sidebar.splitView === modelData.split
                               ? Qt.rgba(themeManager.accentColor.r, themeManager.accentColor.g,
                                         themeManager.accentColor.b, 0.22)
                               : layoutArea.containsMouse ? themeManager.overlayColor : "transparent"
                        border.width: 1
                        border.color: sidebar.splitView === modelData.split
                                      ? themeManager.accentColor : themeManager.borderColor
                        Text {
                            anchors.centerIn: parent
                            text: (layoutChoice.modelData.split ? "▥  " : "▭  ")
                                  + layoutChoice.modelData.label
                            color: themeManager.textColor
                            font.pixelSize: 10; font.bold: true
                        }
                        MouseArea {
                            id: layoutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                sidebar.splitViewRequested(layoutChoice.modelData.split)
                                layoutMenu.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
