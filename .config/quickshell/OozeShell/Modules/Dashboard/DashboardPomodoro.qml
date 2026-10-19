// DashboardPomodoro.qml — DASHBOARD

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

    component Ring: Item {
        id: rg
        property real value: 0
        property color tone: Theme.primary
        property real stroke: 10

        Shape {
            id: sh
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.alpha(rg.tone, 0.18)
                strokeWidth: rg.stroke
                fillColor: "transparent"
                PathAngleArc {
                    centerX: sh.width / 2; centerY: sh.height / 2
                    radiusX: (sh.width - rg.stroke) / 2; radiusY: (sh.height - rg.stroke) / 2
                    startAngle: -90; sweepAngle: 359.9
                }
            }
            ShapePath {
                strokeColor: rg.value > 0.004 ? rg.tone : "transparent"
                strokeWidth: rg.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: sh.width / 2; centerY: sh.height / 2
                    radiusX: (sh.width - rg.stroke) / 2; radiusY: (sh.height - rg.stroke) / 2
                    startAngle: -90; sweepAngle: 359.9 * Math.max(0, Math.min(1, rg.value))
                }
            }
        }
    }

    component Ctl: Rectangle {
        id: b
        property real size: Theme.ds(40)
        property string icon: ""
        property bool primary: false
        property color tone: Theme.primary
        signal clicked()

        width: b.size; height: b.size; radius: b.size / 2
        color: b.primary ? (ma.containsMouse ? Qt.lighter(b.tone, 1.12) : b.tone)
                         : (ma.containsMouse ? Theme.surfaceHigh : Theme.surface)
        scale: ma.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: b.icon
            color: b.primary ? Theme.textOnPrimary : Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: Theme.dfs(17)
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.ds(14)
        spacing: Theme.ds(10)

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.ringSize
            Layout.preferredHeight: root.ringSize

            Ring {
                anchors.fill: parent
                value: root.v.progress
                tone: root.tone
                stroke: Theme.ds(Math.round(10 * root.ringScale))
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.ds(2)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.timeStr
                    color: Theme.text
                    font.bold: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.dfs(Math.round(30 * root.ringScale))
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.phaseLabel + "  ·  " + root.v.round + "/" + root.v.rounds
                    color: root.tone
                    font.pixelSize: Theme.dfs(10)
                    font.family: Theme.fontFamily
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.ds(10)

            Ctl {
                primary: true
                size: root.ctlSize
                tone: root.tone
                icon: root.v.running ? "󰏤" : "󰐊"
                onClicked: PomodoroService.toggle(root.pomoId)
            }
            Ctl { size: root.ctlSize; tone: root.tone; icon: "󰒭"; onClicked: PomodoroService.skip(root.pomoId) }
            Ctl { size: root.ctlSize; tone: root.tone; icon: "󰜉"; onClicked: PomodoroService.reset(root.pomoId) }
        }

        Item { Layout.fillHeight: true }
    }
}
