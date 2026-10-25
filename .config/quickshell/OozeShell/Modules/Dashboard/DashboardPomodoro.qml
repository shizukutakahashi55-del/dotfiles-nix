// DashboardPomodoro.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../Widgets/pomodoro"


Item {
    id: root

    readonly property string pomoId: "dashboard"
    readonly property var v: PomodoroService.view(root.pomoId)
    readonly property string phase: root.v.phase
    readonly property int secs: Math.ceil(root.v.remainMs / 1000)
    function p2(n) { return (n < 10 ? "0" : "") + n }
    readonly property string timeStr: root.p2(Math.floor(root.secs / 60)) + ":" + root.p2(root.secs % 60)
    readonly property string phaseLabel: Translations.t(root.phase === "focus" ? "wgPomoFocus"
                                          : (root.phase === "short" ? "wgPomoShort" : "wgPomoLong"))
    readonly property color tone: root.phase === "focus" ? Theme.primary
                                 : (root.phase === "short" ? "#6fcf97" : "#56b6e8")

    readonly property int preferredWidth: Theme.ds(400)
    readonly property int maxWidth: Theme.ds(460)
    readonly property int preferredHeight: Theme.ds(280)

    property int ringSize: Theme.ds(160)
    readonly property real ringScale: root.ringSize / Theme.ds(160)
    property real ctlSize: Theme.ds(40)

    signal closeRequested()

    // ── Teclado ──
    function handleKey(key, modifiers) {
        if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
            PomodoroService.toggle(root.pomoId); return true
        }
        if (key === Qt.Key_S) { PomodoroService.skip(root.pomoId); return true }
        if (key === Qt.Key_R) { PomodoroService.reset(root.pomoId); return true }
        return false
    }

    // ── Contenido ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(12)
        spacing: Theme.ds(10)

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: Theme.ds(24)
            implicitWidth: phaseText.implicitWidth + Theme.ds(22)
            radius: Theme.cozy ? 3 : height / 2
            color: Qt.alpha(root.tone, 0.28)
            border.width: Theme.cozy ? 2 : 0
            border.color: Theme.ink

            Text {
                id: phaseText
                anchors.centerIn: parent
                text: root.phaseLabel + "  ·  " + root.v.round + "/" + root.v.rounds
                color: root.tone
                font.bold: true
                font.pixelSize: Theme.dfs(10)
                font.family: Theme.fontFamily
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.ringSize
            Layout.preferredHeight: root.ringSize

            MdWavyRing {
                anchors.fill: parent
                value: root.v.progress
                running: root.v.running
                tone: root.tone
                trackColor: Qt.alpha(root.tone, 0.30)
                thickness: Theme.ds(Math.round(8 * root.ringScale))
                amplitude: Theme.ds(2.6 * root.ringScale)
                waveLength: Theme.ds(22 * root.ringScale)
            }

            MdShape {
                anchors.centerIn: parent
                width: parent.width * 0.72
                height: width
                shape: "cookie12"
                color: Qt.alpha(root.tone, root.v.running ? 0.30 : 0.18)
                Behavior on color { ColorAnimation { duration: Theme.animDuration(300) } }
            }

            Text {
                anchors.centerIn: parent
                text: root.timeStr
                color: Theme.text
                font.bold: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dfs(Math.round(26 * root.ringScale))
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.ds(8)

            MdIconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: root.ctlSize
                variant: "tonal"
                glyph: "󰜉"
                onClicked: PomodoroService.reset(root.pomoId)
            }
            MdIconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: Math.round(root.ctlSize * 1.45)
                variant: "filled"
                accent: root.tone
                checkable: true
                toggled: root.v.running
                glyph: root.v.running ? "󰏤" : "󰐊"
                glyphSize: Theme.dfs(22)
                onClicked: PomodoroService.toggle(root.pomoId)
            }
            MdIconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: root.ctlSize
                variant: "tonal"
                glyph: "󰒭"
                onClicked: PomodoroService.skip(root.pomoId)
            }
        }

        Item { Layout.fillHeight: true }
    }
}
