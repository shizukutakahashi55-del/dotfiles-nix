// Dashboard.qml — DASHBOARD

import QtQuick
import Quickshell
import "../../COMMON"


Item {
    id: root

    property string screenName: ""
    property bool open: false


    property bool keepLoaded: false


    property bool warm: false


    readonly property bool dbg: Quickshell.env("OOZE_FRAME_DEBUG") === "1"
    function mark(m) {
        if (root.dbg) console.log("[ooze " + (Date.now() % 100000) + "] " + m)
    }


    readonly property var sectionOrder: header.items.filter(it => !it.action).map(it => it.id)
    readonly property string section: root.sectionOrder.indexOf(AppState.dashboardSection) >= 0
        ? AppState.dashboardSection
        : (root.sectionOrder.length > 0 ? root.sectionOrder[0] : AppState.dashboardSection)
    property string lastSection: root.section
    property int slideDir: 1


    readonly property int headerH: Theme.ds(64)


    readonly property int baseContentH: Theme.ds(224)

    // ── Dos ranuras para las secciones ──────────────────────────


    property var front: slotA
    readonly property var back: root.front === slotA ? slotB : slotA
    readonly property var frontItem: root.front.item


    property int heldContentH: root.baseContentH
    property int heldFullWidth: root.minW
    readonly property int sectionH:
        root.frontItem && root.frontItem.preferredHeight
            ? Math.round(root.frontItem.preferredHeight) : 0
    onSectionHChanged: if (root.sectionH > 0) root.heldContentH = root.sectionH
    readonly property int minContentH: Theme.ds(280)
    readonly property int contentH: Math.max(root.minContentH,
        root.sectionH > 0 ? root.sectionH
        : (root.frontItem ? root.baseContentH : root.heldContentH))
    readonly property int fullHeight: headerH + contentH

    readonly property int minW: Theme.ds(480)
    readonly property int maxW: Theme.ds(500)
    readonly property int sectionMaxW:
        root.frontItem && root.frontItem.maxWidth
            ? root.frontItem.maxWidth : root.maxW
    readonly property int sectionPreferredWidth:
        root.frontItem && root.frontItem.preferredWidth
            ? root.frontItem.preferredWidth : root.minW


    readonly property int liveFullWidth: Math.max(root.minW, header.requiredWidth,
        Math.min(root.sectionMaxW, root.sectionPreferredWidth))
    onLiveFullWidthChanged: if (root.frontItem) root.heldFullWidth = root.liveFullWidth
    readonly property int fullWidth: root.frontItem
        ? root.liveFullWidth : Math.max(root.heldFullWidth, header.requiredWidth)


    property bool sizeAnim: false
    Timer { id: sizeAnimGate; interval: 320; onTriggered: root.sizeAnim = true }
    property real smoothWidth: root.fullWidth
    Behavior on smoothWidth {
        enabled: root.sizeAnim
        NumberAnimation { duration: Motion.dur(Theme.animMs); easing.type: Easing.OutCubic }
    }

    function stepSection(d) {
        const o = root.sectionOrder
        if (o.length < 2) return
        const i = Math.max(0, o.indexOf(root.section))
        AppState.dashboardSection = o[(i + d + o.length) % o.length]
    }

    function jumpSection(n) {
        if (n >= 0 && n < root.sectionOrder.length) AppState.dashboardSection = root.sectionOrder[n]
    }

    function handleKey(key, modifiers) {
        const ctrl = (modifiers & Qt.ControlModifier) !== 0
        const alt = (modifiers & Qt.AltModifier) !== 0
        const shift = (modifiers & Qt.ShiftModifier) !== 0

        if (ctrl && (key === Qt.Key_Left || key === Qt.Key_H)) { root.stepSection(-1); return true }
        if (ctrl && (key === Qt.Key_Right || key === Qt.Key_L)) { root.stepSection(1); return true }
        if (key === Qt.Key_PageUp) { root.stepSection(-1); return true }
        if (key === Qt.Key_PageDown) { root.stepSection(1); return true }
        if (alt && key >= Qt.Key_1 && key <= Qt.Key_9) { root.jumpSection(key - Qt.Key_1); return true }

        const it = root.frontItem
        if (it && it.handleKey && it.handleKey(key, modifiers) === true) return true

        if (ctrl || alt) return false
        switch (key) {
            case Qt.Key_Left:
            case Qt.Key_H:       root.stepSection(-1); return true
            case Qt.Key_Right:
            case Qt.Key_L:       root.stepSection(1); return true
            case Qt.Key_Tab:     root.stepSection(shift ? -1 : 1); return true
            case Qt.Key_Backtab: root.stepSection(-1); return true
        }
        if (key >= Qt.Key_1 && key <= Qt.Key_9) { root.jumpSection(key - Qt.Key_1); return true }
        return false
    }

    signal requestNetwork()
    signal requestBluetooth()
    signal requestAppearance()
    signal requestWalls()
    signal requestAdvancedSettings()

    DashboardHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerH
        section: root.section
        onSectionSelected: s => AppState.dashboardSection = s
        onSectionHover: s => root.preloadSection(s)
    }

    function urlFor(section) {
        switch (section) {
            case "power":       return "DashboardPower.qml"
            case "mpris":       return "DashboardMpris.qml"
            case "performance": return "DashboardPerformance.qml"
            case "audio":       return "DashboardAudio.qml"
            case "notifs":      return "DashboardNotifications.qml"
            case "focus":       return "DashboardFocus.qml"
            case "calendar":    return "DashboardCalendar.qml"
            default:            return "DashboardQuickAccess.qml"
        }
    }


    Loader {
        id: slotA
        property string file: ""
        property bool used: true
        property bool pendingSwap: false
        property bool preloaded: false
        property bool frozen: false
        property real frozenW: 0
        property real frozenH: 0
        property real fade: 1
        property real shift: 0

        x: frozen ? Math.round((root.width - frozenW) / 2) : 0
        y: root.headerH
        width: frozen ? frozenW : root.width
        height: frozen ? frozenH : Math.max(0, root.height - root.headerH)
        active: used && (root.open || root.keepLoaded || root.warm)


        asynchronous: true
        opacity: fade
        visible: fade > 0.01
        enabled: root.front === slotA
        transform: Translate { x: Math.round(slotA.shift) }
        onLoaded: root.slotLoaded(slotA)
    }

    Loader {
        id: slotB
        property string file: ""
        property bool used: false
        property bool pendingSwap: false
        property bool preloaded: false
        property bool frozen: false
        property real frozenW: 0
        property real frozenH: 0
        property real fade: 0
        property real shift: 0

        x: frozen ? Math.round((root.width - frozenW) / 2) : 0
        y: root.headerH
        width: frozen ? frozenW : root.width
        height: frozen ? frozenH : Math.max(0, root.height - root.headerH)
        active: used && (root.open || root.keepLoaded || root.warm)
        asynchronous: true
        opacity: fade
        visible: fade > 0.01
        enabled: root.front === slotB
        transform: Translate { x: Math.round(slotB.shift) }
        onLoaded: root.slotLoaded(slotB)
    }

    Component.onCompleted: {
        const f = root.urlFor(root.section)
        slotA.file = f
        slotA.source = f
    }

    // ── Animaciones de cruce ────────────────────────────────────

    ParallelAnimation {
        id: enterA
        NumberAnimation { target: slotA; property: "fade"; from: 0; to: 1
            duration: Motion.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effects }
        NumberAnimation { target: slotA; property: "shift"; to: 0
            duration: Motion.dur(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
    }
    ParallelAnimation {
        id: enterB
        NumberAnimation { target: slotB; property: "fade"; from: 0; to: 1
            duration: Motion.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effects }
        NumberAnimation { target: slotB; property: "shift"; to: 0
            duration: Motion.dur(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
    }
    ParallelAnimation {
        id: leaveA
        NumberAnimation { target: slotA; property: "fade"; to: 0
            duration: Motion.dur(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsFast }
        NumberAnimation { target: slotA; property: "shift"; to: -root.slideDir * Theme.ds(28)
            duration: Motion.dur(220); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsFast }
        onFinished: root.finishLeave(slotA)
    }
    ParallelAnimation {
        id: leaveB
        NumberAnimation { target: slotB; property: "fade"; to: 0
            duration: Motion.dur(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsFast }
        NumberAnimation { target: slotB; property: "shift"; to: -root.slideDir * Theme.ds(28)
            duration: Motion.dur(220); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsFast }
        onFinished: root.finishLeave(slotB)
    }

    function enter(s) {
        if (s === slotA) { leaveA.stop(); enterA.restart() }
        else             { leaveB.stop(); enterB.restart() }
    }
    function leave(s) {
        if (s === slotA) { enterA.stop(); leaveA.restart() }
        else             { enterB.stop(); leaveB.restart() }
    }
    function stopLeave(s) {
        if (s === slotA) leaveA.stop()
        else leaveB.stop()
    }
    function stopAnims() { enterA.stop(); enterB.stop(); leaveA.stop(); leaveB.stop() }


    function finishLeave(s) {
        s.frozen = false
        s.pendingSwap = false
        s.preloaded = false
        s.used = false
        s.file = ""
        s.fade = 0
        s.shift = 0
        root.mark("cruce terminado")
    }


    function showDirect(file) {
        root.stopAnims()
        const f = root.front
        const b = root.back
        preloadExpire.stop()
        b.frozen = false
        b.pendingSwap = false
        b.preloaded = false
        b.used = false
        b.file = ""
        b.fade = 0
        b.shift = 0
        f.frozen = false
        f.pendingSwap = false
        f.used = true
        f.fade = 1
        f.shift = 0
        if (f.file !== file) {
            f.file = file
            f.source = file
        }
    }

    // ── Precarga al pasar el mouse por un botón del header ─────────


    Timer { id: preloadExpire; interval: 2500; onTriggered: root.dropPreload() }

    function preloadSection(section) {
        if (!root.open || !root.frontItem) return
        const file = root.urlFor(section)
        const f = root.front
        const b = root.back
        if (f.file === file || b.pendingSwap) return

        if (b.fade > 0.01) return
        if (b.used && b.file === file) { preloadExpire.restart(); return }
        b.frozen = false
        b.fade = 0
        b.shift = 0
        b.file = file
        b.source = file
        b.preloaded = true
        b.used = true
        root.mark("precarga: " + file)
        preloadExpire.restart()
    }

    function dropPreload() {
        const b = root.back
        if (b.preloaded && !b.pendingSwap) {
            b.preloaded = false
            b.used = false
            b.file = ""
            root.mark("precarga descartada")
        }
    }


    function syncSection() {
        const file = root.urlFor(root.section)
        const f = root.front
        const b = root.back

        const prevIdx = root.sectionOrder.indexOf(root.lastSection)
        const nextIdx = root.sectionOrder.indexOf(root.section)
        if (prevIdx >= 0 && nextIdx >= 0 && prevIdx !== nextIdx)
            root.slideDir = nextIdx > prevIdx ? 1 : -1
        root.lastSection = root.section
        root.mark("sección pedida: " + file)
        if (!root.open || !f.item) { root.showDirect(file); return }
        if (f.file === file) {

            if (b.pendingSwap) {
                b.pendingSwap = false
                b.preloaded = false
                b.used = false
                b.file = ""
                b.fade = 0
            }
            return
        }
        if (b.pendingSwap && b.file === file) return
        preloadExpire.stop()

        if (b.used && b.preloaded && b.file === file) {
            b.preloaded = false
            b.shift = root.slideDir * Theme.ds(40)
            b.pendingSwap = true
            root.mark("precarga aprovechada: " + file)
            if (b.item) root.slotLoaded(b)
            return
        }

        root.stopLeave(b)
        b.frozen = false
        b.fade = 0
        b.shift = root.slideDir * Theme.ds(40)
        b.file = file
        b.source = file
        b.preloaded = false
        b.pendingSwap = true
        b.used = true
    }


    function slotLoaded(s) {
        root.mark("sección cargada: " + s.file)
        let swapped = false
        if (s.pendingSwap) {
            s.pendingSwap = false
            swapped = true
            const old = root.front
            if (old !== s) {

                old.frozenW = old.width
                old.frozenH = old.height
                old.frozen = true
                root.front = s
                root.leave(old)
            }
        } else if (s !== root.front) {
            return
        }
        root.heldFullWidth = root.liveFullWidth
        if (root.sectionH > 0) root.heldContentH = root.sectionH

        if (swapped || root.open) root.enter(s)
    }

    Connections {
        target: AppState
        function onDashboardSectionChanged() { root.syncSection() }
    }


    onOpenChanged: {
        root.sizeAnim = false
        if (root.open) sizeAnimGate.restart()
        else sizeAnimGate.stop()
        if (!root.open) return
        root.showDirect(root.urlFor(root.section))
        if (AppState.dashboardSection !== root.section) AppState.dashboardSection = root.section
    }

    Connections {
        target: root.frontItem
        ignoreUnknownSignals: true
        function onRequestNetwork() { root.requestNetwork() }
        function onRequestBluetooth() { root.requestBluetooth() }
        function onRequestAppearance() { root.requestAppearance() }
        function onRequestWalls() { root.requestWalls() }
        function onRequestAdvancedSettings() { root.requestAdvancedSettings() }
        function onCloseRequested() { AppState.closeDashboard() }
    }
}
