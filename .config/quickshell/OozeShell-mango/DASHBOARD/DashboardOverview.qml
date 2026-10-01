import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"

// DashboardOverview — la vista de workspaces (OVERVIEW/Overview.qml).
Item {
    id: root

    // ─── Tamaño que pide la sección ─────────────────────────────
    readonly property int cardW: Theme.ds(160)
    readonly property int cardPad: Theme.ds(6)
    readonly property int headH: Theme.ds(22)
    readonly property int gap: Theme.ds(8)
    readonly property int pad: Theme.ds(14)
    readonly property int maxColumns: 4
    readonly property int minColumns: 3

    readonly property real miniW: cardW - cardPad * 2
    readonly property real miniH: miniW * aspect
    readonly property real cardH: cardPad * 2 + headH + Theme.ds(6) + miniH

    readonly property int columns: Math.max(1, Math.min(count, maxColumns))
    readonly property int panelColumns: Math.max(columns, minColumns)
    readonly property int rows: Math.max(1, Math.ceil(count / columns))

    readonly property int preferredWidth:
        panelColumns * cardW + (panelColumns - 1) * gap + pad * 2
    readonly property int maxWidth: maxColumns * cardW + (maxColumns - 1) * gap + pad * 2
    readonly property int preferredHeight: Math.round(Math.max(Theme.ds(190),
        rows * cardH + (rows - 1) * gap + pad * 2))

    signal closeRequested()

    readonly property string screenName: AppState.dashboardScreen

    // ─── Workspaces ─────────────────────────────────────────────
    readonly property var workspaceList: MangoIpc.workspacesFor(root.screenName, false)
    readonly property int count: workspaceList.length

    property int selected: 0
    onCountChanged: if (selected >= count) selected = Math.max(0, count - 1)

    function activeIndex() {
        const list = root.workspaceList
        let i = list.findIndex(w => w.active && (w.monitor?.name ?? root.screenName) === root.screenName)
        if (i < 0) i = list.findIndex(w => w.active)
        return Math.max(0, i)
    }

    Component.onCompleted: {
        root.refresh(true)
        root.selected = root.activeIndex()
    }

    // ─── Ventanas y monitores (mmsg, via MangoIpc) ──────────────────────
    // MangoIpc mantiene ventanas y monitores al dia por `mmsg watch`
    property var clients: MangoIpc.clientsCompat
    property var monitors: MangoIpc.monitorsCompat

    readonly property real aspect: {
        const m = root.monitors.find(x => x.name === root.screenName) ?? root.monitors[0]
        if (!m || !m.width || !m.height) return 9 / 16
        const rot = (m.transform % 2) === 1
        const w = rot ? m.height : m.width
        const h = rot ? m.width : m.height
        return Math.max(0.35, Math.min(1.0, h / w))
    }

    // (sin polling: ver MangoIpc)
    function refresh(withMonitors) {}

    function monitorOf(c) {
        return root.monitors.find(m => m.name === c.monitor) ?? root.monitors[0] ?? null
    }

    function relRect(c) {
        const m = root.monitorOf(c)
        if (!m || !c.at || !c.size) return { x: 0, y: 0, w: 1, h: 1 }
        const rot = (m.transform % 2) === 1
        const s = m.scale > 0 ? m.scale : 1
        const mw = (rot ? m.height : m.width) / s
        const mh = (rot ? m.width : m.height) / s
        const x = Math.max(0, Math.min(1, (c.at[0] - m.x) / mw))
        const y = Math.max(0, Math.min(1, (c.at[1] - m.y) / mh))
        return {
            x: x, y: y,
            w: Math.max(0, Math.min(1 - x, c.size[0] / mw)),
            h: Math.max(0, Math.min(1 - y, c.size[1] / mh))
        }
    }

    function windowsOf(wsId) {
        const out = []
        const list = root.clients
        for (let i = 0; i < list.length; i++) {
            const c = list[i]
            if (!c.tags || c.tags.indexOf(wsId) < 0 || c.monitor !== root.screenName) continue
            const r = root.relRect(c)
            out.push({
                address: c.address,
                cls: c["class"] || c.initialClass || "",
                title: c.title || "",
                rx: r.x, ry: r.y, rw: r.w, rh: r.h,
                floating: !!c.floating,
                focused: c.focusHistoryID === 0
            })
        }
        out.sort((a, b) => (a.floating ? 1 : 0) - (b.floating ? 1 : 0))
        return out
    }

    function iconFor(appId) {
        const entry = appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
        const name = (entry && entry.icon) ? entry.icon : appId
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function toplevelFor(address) {
        return MangoIpc.toplevelFor(address)
    }

    // ─── Acciones ───────────────────────────────────────────────
    function goTo(ws) {
        if (!ws) return
        ws.activate()
        root.closeRequested()
    }

    function goToId(id) {
        const ws = root.workspaceList.find(w => w.id === id)
        if (ws) ws.activate()
        else MangoIpc.viewTag(id, root.screenName)
        root.closeRequested()
    }

    function focusWindow(ws, address) {
        ws.activate()
        MangoIpc.focusClient(address)
        root.closeRequested()
    }

    // ─── Teclado (lo reenvía Dashboard.handleKey) ───────────────
    function step(d) {
        if (root.count > 0) root.selected = (root.selected + d + root.count) % root.count
    }

    function jump(dir) {
        const s = root.columns
        let t = root.selected + dir * s
        if (t >= root.count && Math.floor(root.selected / s) < Math.floor((root.count - 1) / s))
            t = root.count - 1
        if (t >= 0 && t < root.count) root.selected = t
    }

    // true = la tecla se usó
    function handleKey(key, modifiers) {
        const shift = (modifiers & Qt.ShiftModifier) !== 0

        switch (key) {
            case Qt.Key_Left:
            case Qt.Key_H:       root.step(-1); return true
            case Qt.Key_Right:
            case Qt.Key_L:       root.step(1); return true
            case Qt.Key_Up:
            case Qt.Key_K:       root.jump(-1); return true
            case Qt.Key_Down:
            case Qt.Key_J:       root.jump(1); return true
            case Qt.Key_Tab:     root.step(shift ? -1 : 1); return true
            case Qt.Key_Backtab: root.step(-1); return true
            case Qt.Key_Home:    root.selected = 0; return true
            case Qt.Key_End:     root.selected = Math.max(0, root.count - 1); return true
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:   root.goTo(root.workspaceList[root.selected]); return true
        }

        if (key >= Qt.Key_1 && key <= Qt.Key_9) { root.goToId(key - Qt.Key_0); return true }
        if (key === Qt.Key_0) { root.goToId(10); return true }
        return false
    }

    // ─── Tarjetas ───────────────────────────────────────────────
    GridLayout {
        anchors.centerIn: parent
        columns: root.columns
        columnSpacing: root.gap
        rowSpacing: root.gap

        Repeater {
            model: root.workspaceList

            delegate: SkinRect {
                id: card
                required property var modelData      // workspace (MangoIpc)
                required property int index

                readonly property bool isSelected: root.selected === card.index
                readonly property bool isCurrent: card.modelData.active
                readonly property var wins: root.windowsOf(card.modelData.id)

                Layout.preferredWidth: root.cardW
                Layout.preferredHeight: root.cardH
                radius: Theme.ds(12)
                color: card.isSelected ? Theme.surfaceHigh : Theme.surface
                inkColor: card.isSelected ? Theme.primary : Theme.ink
                raised: Theme.cozy
                depth: 2
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

                scale: Theme.cozy ? 1.0 : (cardArea.pressed ? 0.97 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.selected = card.index
                    onClicked: root.goTo(card.modelData)
                }

                ColumnLayout {
                    x: root.cardPad
                    y: root.cardPad
                    width: parent.width - root.cardPad * 2
                    spacing: Theme.ds(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.headH
                        spacing: Theme.ds(6)

                        Rectangle {
                            Layout.preferredWidth: root.headH
                            Layout.preferredHeight: root.headH
                            radius: Theme.ds(7)
                            color: card.isCurrent ? Theme.primary : Theme.bg
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }

                            Text {
                                anchors.centerIn: parent
                                text: card.modelData.id
                                color: card.isCurrent ? Theme.textOnPrimary : Theme.text
                                font.bold: true
                                font.pixelSize: Theme.dfs(11)
                                font.family: Theme.fontFamily
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: text !== ""
                            text: String(card.modelData.name) !== String(card.modelData.id)
                                  ? String(card.modelData.name) : ""
                            color: Theme.subtext
                            font.pixelSize: Theme.dfs(10)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillWidth: true }

                        Text {
                            visible: text !== ""
                            text: card.modelData.urgent ? "♡" : (card.isCurrent ? "❄" : "")
                            color: card.modelData.urgent ? Theme.error : Theme.primary
                            font.pixelSize: Theme.dfs(13)
                            font.family: Theme.fontFamily
                        }
                        Text {
                            visible: card.wins.length > 0
                            text: card.wins.length
                            color: Theme.subtext
                            font.pixelSize: Theme.dfs(10)
                            font.family: Theme.fontFamily
                        }
                    }

                    SkinRect {
                        Layout.preferredWidth: root.miniW
                        Layout.preferredHeight: root.miniH
                        radius: Theme.ds(8)
                        color: Theme.bg
                        inkColor: Theme.edge

                        Text {
                            anchors.centerIn: parent
                            visible: card.wins.length === 0
                            text: Translations.t("overviewEmpty")
                            color: Theme.subtext
                            font.pixelSize: Theme.dfs(10)
                            font.family: Theme.fontFamily
                        }

                        Item {
                            id: inner
                            anchors.fill: parent
                            anchors.margins: Theme.ds(3)

                            Repeater {
                                model: card.wins

                                delegate: Rectangle {
                                    id: win
                                    required property var modelData

                                    x: win.modelData.rx * inner.width
                                    y: win.modelData.ry * inner.height
                                    width: Math.max(6, win.modelData.rw * inner.width)
                                    height: Math.max(6, win.modelData.rh * inner.height)
                                    z: win.modelData.floating ? 2 : 1
                                    radius: Theme.ds(4)
                                    color: Theme.surface
                                    clip: true

                                    readonly property var toplevel: root.toplevelFor(win.modelData.address)

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: Math.min(Theme.ds(24), Math.min(win.width, win.height) * 0.6)
                                        height: width
                                        visible: width >= 10 && !shot.hasContent
                                        asynchronous: true
                                        source: root.iconFor(win.modelData.cls)
                                    }

                                    // En vivo solo en el workspace activo; en los demás,
                                    // un cuadro fijo (más liviano).
                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        captureSource: win.toplevel
                                        live: card.isCurrent
                                        paintCursor: false
                                        visible: hasContent
                                        Component.onCompleted: if (!live && captureSource) captureFrame()
                                        onCaptureSourceChanged: if (!live && captureSource) captureFrame()
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.ds(4)
                                        z: 3
                                        color: winArea.containsMouse
                                               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                               : "transparent"
                                        border.width: win.modelData.focused ? 2 : Theme.bw1
                                        border.color: win.modelData.focused ? Theme.primary : Theme.edge
                                        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                                    }

                                    MouseArea {
                                        id: winArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: root.selected = card.index
                                        onClicked: root.focusWindow(card.modelData, win.modelData.address)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
