import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: workspace

    property bool splitView: false
    property string leftSessionId: ""
    property string rightSessionId: ""
    property string activeSide: "left"

    function sessionInfo(sessionId) {
        var sessions = agentTerminalService.sessions
        for (var i = 0; i < sessions.length; ++i) {
            if (sessions[i].id === sessionId)
                return sessions[i]
        }
        return ({ id: "", label: "No session selected", provider: "", model: "" })
    }

    function reconcileSelections() {
        var sessions = agentTerminalService.sessions
        var leftFound = false
        var rightFound = false
        for (var i = 0; i < sessions.length; ++i) {
            if (sessions[i].id === leftSessionId) leftFound = true
            if (sessions[i].id === rightSessionId) rightFound = true
        }
        if (!leftFound)
            leftSessionId = sessions.length > 0 ? sessions[0].id : ""
        if (!rightFound)
            rightSessionId = sessions.length > 1 ? sessions[1].id
                                                   : (sessions.length > 0 ? sessions[0].id : "")
    }

    Component.onCompleted: reconcileSelections()

    Connections {
        target: agentTerminalService
        function onSessionsChanged() { workspace.reconcileSelections() }
        function onErrorOccurred(message) { toastModel.show(message, 4000) }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 38
        spacing: 7

        AgentSessionSidebar {
            Layout.preferredWidth: workspace.splitView ? 210 : 248
            Layout.fillHeight: true
            sideLabel: "LEFT"
            workspaceHeader: true
            splitView: workspace.splitView
            selectedSessionId: workspace.leftSessionId
            onSplitViewRequested: (enabled) => workspace.splitView = enabled
            onSessionSelected: (sessionId) => {
                workspace.leftSessionId = sessionId
                workspace.activeSide = "left"
            }
        }

        AgentTerminalPane {
            id: leftPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            sessionId: workspace.leftSessionId
            sessionLabel: workspace.sessionInfo(sessionId).label
            sessionProvider: workspace.sessionInfo(sessionId).provider
            sessionModel: workspace.sessionInfo(sessionId).model
            paneActive: workspace.activeSide === "left"
            onActivated: workspace.activeSide = "left"
        }

        AgentTerminalPane {
            id: rightPane
            visible: workspace.splitView
            Layout.fillWidth: true
            Layout.fillHeight: true
            sessionId: workspace.rightSessionId
            sessionLabel: workspace.sessionInfo(sessionId).label
            sessionProvider: workspace.sessionInfo(sessionId).provider
            sessionModel: workspace.sessionInfo(sessionId).model
            paneActive: workspace.activeSide === "right"
            onActivated: workspace.activeSide = "right"
        }

        AgentSessionSidebar {
            visible: workspace.splitView
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            sideLabel: "RIGHT"
            splitView: workspace.splitView
            selectedSessionId: workspace.rightSessionId
            onSessionSelected: (sessionId) => {
                workspace.rightSessionId = sessionId
                workspace.activeSide = "right"
            }
        }
    }
}
