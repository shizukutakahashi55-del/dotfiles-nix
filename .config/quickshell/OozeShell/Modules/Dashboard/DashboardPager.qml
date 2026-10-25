// DashboardPager.qml — DASHBOARD

import QtQuick
import "../../COMMON"


Item {
    id: root

    property int count: 0
    property int current: 0
    signal pageSelected(int index)

    // ── Medidas ──

    readonly property int slot: Theme.ds(12)
    readonly property int gap: Theme.ds(6)
    readonly property int padX: Theme.ds(8)
    readonly property int dotSize: Theme.ds(6)
    readonly property int thumbW: Theme.ds(20)
    readonly property int thumbH: Theme.ds(8)
    readonly property int step: root.slot + root.gap

    implicitWidth: root.count > 0 ? root.count * root.slot + (root.count - 1) * root.gap + root.padX * 2 : 0
    implicitHeight: Theme.ds(22)

    function centerOf(i) { return root.padX + i * root.step + root.slot / 2 }

    function indexAt(x) {
        const i = Math.floor((x - root.padX + root.gap / 2) / root.step)
        return Math.max(0, Math.min(root.count - 1, i))
    }

    // ── Pista ──

    Rectangle {
        anchors.fill: parent
        radius: Theme.cozy ? 0 : height / 2
        color: Theme.cozy ? "transparent" : MdTokens.container
        border.width: 1
        border.color: MdTokens.edgeSoft
    }

    // ── Puntos ──

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: dot
            required property int index
            readonly property bool hot: hit.containsMouse && hit.hoverIndex === dot.index && dot.index !== root.current

            x: Math.round(root.centerOf(dot.index) - width / 2)
            y: Math.round((root.height - height) / 2)
            width: dot.hot ? root.dotSize + Theme.ds(2) : root.dotSize
            height: width
            radius: Theme.cozy ? 0 : width / 2
            color: dot.hot ? Theme.mix(Theme.subtext, Theme.text, 0.5) : MdTokens.edgeSoft
            opacity: dot.index === root.current ? 0 : 1
            Behavior on width { NumberAnimation { duration: Theme.animDuration(120) } }
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(140) } }
        }
    }

    // ── Indicador ──

    Rectangle {
        id: thumb
        visible: root.count > 0 && root.current >= 0
        property real cx: root.centerOf(Math.max(0, root.current))
        width: hit.pressed ? root.thumbW + Theme.ds(4) : root.thumbW
        height: root.thumbH
        x: Math.round(thumb.cx - width / 2)
        y: Math.round((root.height - height) / 2)
        radius: Theme.cozy ? 0 : height / 2
        color: Theme.primary
        Behavior on cx {
            NumberAnimation {
                duration: Theme.animDuration(260)
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
        }
        Behavior on width { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutCubic } }
    }

    // ── Ratón ──

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        property int hoverIndex: -1
        property real wheelAcc: 0

        function go(x) {
            const i = root.indexAt(x)
            hit.hoverIndex = i
            if (i !== root.current) root.pageSelected(i)
        }

        onPressed: mouse => hit.go(mouse.x)
        onPositionChanged: mouse => {
            hit.hoverIndex = root.indexAt(mouse.x)
            if (hit.pressed) hit.go(mouse.x)
        }
        onExited: hit.hoverIndex = -1
        onWheel: wheel => {
            hit.wheelAcc += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            if (Math.abs(hit.wheelAcc) < 120) return
            const d = hit.wheelAcc > 0 ? -1 : 1
            hit.wheelAcc = 0
            const i = Math.max(0, Math.min(root.count - 1, root.current + d))
            if (i !== root.current) root.pageSelected(i)
        }
    }
}
