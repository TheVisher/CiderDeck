import QtQuick
import QtQuick.Layouts

RowLayout {
    id: settingsRow
    Layout.fillWidth: true
    spacing: 12

    property string label: ""

    Text {
        text: settingsRow.label
        color: themeManager.textColor
        font.pixelSize: 13
        Layout.preferredWidth: 130
    }
}
