// PillOptions.qml — PILL

import QtQuick
import "../../COMMON"
import "../../Services/Lang"
import "../Dashboard"


Item {
    id: root

    property bool active: false

    signal picked(string section)
    signal hovered(string section)

    DashboardSections { id: sections }
    DashboardNav { id: nav }

    // ── Medidas ──

    readonly property var entries: sections.forPill
    readonly property int count: root.entries.length
    readonly property int btn: Theme.ds(42)
    readonly property int gap: Theme.ds(8)
    readonly property int padX: Theme.ds(14)
    readonly property int padTop: Theme.ds(12)
    readonly property int padBottom: Theme.ds(8)
    readonly property int capH: Theme.ds(18)

    implicitWidth: root.count * root.btn + Math.max(0, root.count - 1) * root.gap + root.padX * 2
    implicitHeight: root.padTop + root.btn + Theme.ds(6) + root.capH + root.padBottom

    // ── Selección ──

    property int sel: 0
    property bool kbd: false

    onActiveChanged: {
        if (!root.active) return
        const i = root.entries.findIndex(e => e.id === AppState.dashboardSection)
        root.sel = i >= 0 ? i : 0
        root.kbd = false
    }

    HoverHandler { onPointChanged: root.kbd = false }

    Timer {
        id: dwell
        interval: 220
        onTriggered: {
            const e = root.entries[root.sel]
            if (e) root.hovered(e.id)
        }
    }

    function choose(id) {
        dwell.stop()
        root.picked(id)
    }

    function moveTo(i) {
        root.kbd = true
        root.sel = i
        dwell.restart()
    }

    // ── Teclado ──

    function handleKey(key, modifiers) {
        const n = root.entries.length
        if (n === 0) return false
        const shift = (modifiers & Qt.ShiftModifier) !== 0

        if (nav.isDir(key)) {
            if (key === Qt.Key_Left || key === Qt.Key_H) root.moveTo((root.sel - 1 + n) % n)
            else if (key === Qt.Key_Right || key === Qt.Key_L) root.moveTo((root.sel + 1) % n)
            return true
        }
        if (key === Qt.Key_Tab && !shift) { root.moveTo((root.sel + 1) % n); return true }
        if (key === Qt.Key_Backtab || (key === Qt.Key_Tab && shift)) { root.moveTo((root.sel - 1 + n) % n); return true }
        if (nav.isAccept(key)) { root.choose(root.entries[root.sel].id); return true }
        if (key >= Qt.Key_1 && key <= Qt.Key_9) {
            const i = key - Qt.Key_1
            if (i < n) root.choose(root.entries[i].id)
            return true
        }
        return false
    }

    // ── Resaltado ──

    SkinRect {
        id: slider
        visible: root.count > 0
        y: root.padTop
        width: root.btn
        height: root.btn
        radius: Theme.cozy ? Theme.ds(10) : root.btn / 2
        raised: Theme.cozy
        depth: Theme.cozy ? 3 : 2
        inkColor: Theme.ink
        color: Theme.primary

        property real sx: root.padX + root.sel * (root.btn + root.gap)
        x: Math.round(slider.sx)
        Behavior on sx {
            NumberAnimation {
                duration: Theme.animDuration(Theme.cozy ? 200 : 260)
                easing.type: Easing.OutBack
                easing.overshoot: Theme.cozy ? 0.4 : 0.9
            }
        }
    }

    // ── Botones ──

    Repeater {
        model: root.entries
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool current: root.sel === cell.index

            x: root.padX + cell.index * (root.btn + root.gap)
            y: root.padTop
            width: root.btn
            height: root.btn

            Rectangle {
                anchors.fill: parent
                radius: Theme.cozy ? Theme.ds(10) : width / 2
                color: cell.current ? "transparent" : (mouse.containsMouse ? MdTokens.containerHighest : MdTokens.containerHigh)
                border.width: (cell.current || Theme.cozy) ? 0 : 1
                border.color: MdTokens.edgeSoft
                visible: !Theme.cozy || !cell.current
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.icon
                color: cell.current ? Theme.textOnPrimary : Theme.primary
                font.pixelSize: Theme.dfs(17)
                font.family: Theme.monoFamily
                scale: cell.current ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.kbd = false; root.sel = cell.index; dwell.restart() }
                onClicked: root.choose(cell.modelData.id)
            }
        }
    }

    // ── Etiqueta ──

    Text {
        id: caption
        y: root.padTop + root.btn + Theme.ds(6)
        width: parent.width - root.padX * 2
        x: root.padX
        height: root.capH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.entries[root.sel] ? Translations.t(root.entries[root.sel].labelKey) : ""
        color: Theme.text
        font.pixelSize: Theme.dfs(11)
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }
}
