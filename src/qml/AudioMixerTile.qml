import QtQuick

Card {
    id: mixerTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1
    readonly property real railScale: contentScale

    readonly property int primaryGroupIdx: settings.primaryGroup || 0
    readonly property var groupList: audioMixerService ? audioMixerService.groups : []
    readonly property var grp: groupList[primaryGroupIdx] || ({})
    readonly property bool isGeneral: grp.isGeneral || false
    readonly property int audioTick: audioManager ? audioManager.refreshTick : 0
    readonly property int volume: {
        void(audioTick)
        if (isGeneral) return audioManager ? audioManager.defaultVolume : 0
        if (audioManager) {
            var apps = grp.apps || []
            for (var i = 0; i < apps.length; i++) {
                var streams = audioManager.findStreamsByApp(apps[i])
                if (streams.length > 0) return audioManager.appVolume(apps[i])
            }
        }
        return grp.volume || 0
    }
    readonly property bool muted: {
        void(audioTick)
        if (isGeneral) return audioManager ? audioManager.defaultMuted : false
        if (audioManager) {
            var apps = grp.apps || []
            for (var i = 0; i < apps.length; i++) {
                var streams = audioManager.findStreamsByApp(apps[i])
                if (streams.length > 0) return audioManager.appMuted(apps[i])
            }
        }
        return grp.muted || false
    }
    readonly property string groupName: grp.name || "General"
    readonly property color channelColor: settings.barColor || themeManager.accentColor

    function setVolume(value) {
        var percent = Math.round(Math.max(0, Math.min(1, value)) * 100)
        if (isGeneral) audioManager.setDefaultVolume(percent)
        else audioMixerService.setGroupVolume(primaryGroupIdx, percent)
    }

    function toggleMute() {
        if (isGeneral) audioManager.setDefaultMuted(!muted)
        else audioMixerService.setGroupMuted(primaryGroupIdx, !muted)
    }

    VerticalSlider {
        anchors.fill: parent
        anchors.bottomMargin: 34
        label: mixerTile.groupName
        detail: mixerTile.isGeneral ? "SYSTEM OUTPUT" : ((mixerTile.grp.apps || []).length + " ASSIGNED")
        value: mixerTile.volume / 100
        muted: mixerTile.muted
        accentColor: mixerTile.channelColor
        sliderThickness: settings.sliderThickness || 1
        knobSize: settings.knobSize || 1
        knobShape: settings.knobShape || "pill"
        knobColor: settings.knobColor || "#f5f7fa"
        iconColor: settings.iconColor || themeManager.textColor
        valueColor: settings.percentColor || themeManager.textColor
        showValue: settings.showPercent !== false
        showIcon: settings.showIcon !== false
        iconSource: mixerTile.muted
                    ? "qrc:/icons/lucide/volume-x.svg"
                    : mixerTile.volume < 35
                      ? "qrc:/icons/lucide/volume-1.svg"
                      : "qrc:/icons/lucide/volume-2.svg"
        contentScale: mixerTile.railScale
        tileHost: mixerTile
        tileId: mixerTile.tileId
        tileSettings: mixerTile.settings
        contentEditMode: mixerTile.contentEditMode
        selectedElement: mixerTile.selectedElement
        onValueRequested: (value) => mixerTile.setVolume(value)
        onIconClicked: mixerTile.toggleMute()
    }

    IconTouchButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 34
        height: 34
        iconSize: 15
        source: "qrc:/icons/lucide/sliders-horizontal.svg"
        iconColor: themeManager.secondaryTextColor
        enabled: !mixerTile.contentEditMode
        onClicked: mixerOverlay.open(mixerTile.settings)
    }
}
