// DashboardBack.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"


Item {
    id: root

    property string section: ""
    property int count: 0
    property int current: 0
    signal backRequested()
    signal pageSelected(int index)

    DashboardSections { id: sections }
    readonly property var entry: sections.all.find(e => e.id === root.section)

    // ── Línea inferior ──

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.cozy ? 2 : 1
        color: Theme.cozy ? Theme.ink : Theme.divider
    }

    // ── Contenido ──

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.ds(10)
        anchors.rightMargin: Theme.ds(14)
        spacing: Theme.ds(10)

        Rectangle {
            id: backBtn
            Layout.preferredWidth: Theme.ds(30)
            Layout.preferredHeight: Theme.ds(30)
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.cozy ? Theme.ds(8) : width / 2
            color: backMouse.containsMouse ? (Theme.cozy ? Theme.surface : MdTokens.controlStrong) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            scale: Theme.cozy ? 1.0 : (backMouse.pressed ? 0.90 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutBack } }

            Text {
                anchors.centerIn: parent
                text: OozeIcons.back
                color: Theme.text
                font.pixelSize: Theme.dfs(18)
                font.family: Theme.monoFamily
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            visible: root.entry !== undefined
            text: root.entry ? root.entry.icon : ""
            color: Theme.primary
            font.pixelSize: Theme.dfs(15)
            font.family: Theme.monoFamily
        }

        Text {
            Layout.fillWidth: true
            text: root.entry ? Translations.t(root.entry.labelKey) : ""
            color: Theme.text
            font.pixelSize: Theme.dfs(13)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }

        // ── Indicador de página ──

        DashboardPager {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            count: root.count
            current: root.current
            onPageSelected: i => root.pageSelected(i)
        }

        Rectangle {
            Layout.preferredWidth: escText.implicitWidth + Theme.ds(12)
            Layout.preferredHeight: Theme.ds(20)
            radius: Theme.cozy ? 0 : Theme.ds(6)
            color: "transparent"
            border.width: 1
            border.color: MdTokens.edgeSoft
            Text {
                id: escText
                anchors.centerIn: parent
                text: "Esc"
                color: Theme.mix(Theme.subtext, Theme.text, 0.4)
                font.pixelSize: Theme.dfs(9)
                font.family: Theme.fontFamily
            }
        }
    }
}
