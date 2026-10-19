// Pill.qml — PILL

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../Taskbar"
import "../Dashboard"
import "../../Services/Notify"
import "../../Services/Lang"


Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""

    // ── Fullscreen ──────────────────────────────────────────────────


    readonly property bool suppressed: FullscreenState.isOn(targetScreen)
    onSuppressedChanged: {
        if (root.suppressed) {
            if (root.dashboardOpenHere) AppState.closeDashboard()
            root.closeMenu()
        }
    }


    signal notificationButtonClicked(var screen)
    signal requestNetwork(var screen)
    signal requestBluetooth(var screen)
    signal requestAppearance(var screen)
    signal requestWalls(var screen)
    signal requestAdvancedSettings(var screen)
    signal trayMenuOpened()

    signal requestCloseNotify()


    property bool notifyOpen: false
    property string notifyScreen: ""
    readonly property bool notifOpenHere: root.notifyOpen && root.notifyScreen === root.screenName


    property bool popupOpen: false

    readonly property bool dashboardOpenHere:
        AppState.dashboardOpen && AppState.dashboardScreen === root.screenName

    // ── Precarga del Dashboard ───────────────────────────────────────


    property bool warm: false
    Timer { id: warmOn;  interval: 150;  onTriggered: root.warm = true }
    Timer { id: warmOff; interval: 4000; onTriggered: root.warm = false }
    function noteHover(inside) {
        if (inside) { warmOff.stop(); if (!root.warm && !root.dashboardOpenHere) warmOn.restart() }
        else { warmOn.stop(); warmOff.restart() }
    }

    // ── Lista del taskbar plegado (Modules/Taskbar/TaskbarList.qml) ──────────

    property bool taskbarMenuOpen: false
    function closeTaskbarMenu() { root.taskbarMenuOpen = false }
    function openTaskbarMenu(iconItem) {
        if (root.taskbarMenuOpen) { root.closeTaskbarMenu(); return }

        if (AppState.dashboardOpen) AppState.closeDashboard()
        if (root.notifyOpen) root.requestCloseNotify()
        root.taskbarMenuOpen = true
    }

    // ── Menús que nacen de la píldora ────────────────────────────────


    readonly property string menuKind: root.notifOpenHere ? "notif" : (root.taskbarMenuOpen ? "taskbar" : "")

    property string lastKind: "notif"
    onMenuKindChanged: { if (root.menuKind !== "") root.lastKind = root.menuKind }
    function closeMenu() {
        if (root.notifyOpen) root.requestCloseNotify()
        root.closeTaskbarMenu()
    }

    function closeAll() {
        if (root.dashboardOpenHere) AppState.closeDashboard()
        root.closeMenu()
    }

    Connections {
        target: AppState
        function onDashboardOpenChanged() {
            if (AppState.dashboardOpen) root.closeMenu()
        }
    }

    onNotifOpenHereChanged: { if (root.notifOpenHere) root.closeTaskbarMenu() }

    Connections {
        target: pillTaskbar
        function onCountChanged() {
            if (pillTaskbar.count === 0) root.closeTaskbarMenu()
        }
    }

    // ── Auto-hide ───────────────────────────────────────────────────


    property bool hiddenHere: false
    readonly property bool keepVisible:
        !AppState.pillAutoHide
        || root.dashboardOpenHere
        || root.menuKind !== ""
        || root.wsOverride
        || surfaceHover.hovered
        || trigger.hovered
        || root.popupOpen
        || (AppState.pillTraySync && sideTray.keepVisible)

    function applyHidden(v) {
        root.hiddenHere = v
        AppState.pillHiddenNow = v
    }
    onKeepVisibleChanged: {
        if (root.keepVisible) { hideTimer.stop(); root.applyHidden(false) }
        else hideTimer.restart()
    }
    Component.onCompleted: {
        root.lastWsId = root.activeWsId
        if (!root.keepVisible) hideTimer.restart()
        root.reportIsland()
    }
    Component.onDestruction: IslandState.clearPill(root.screenName, "center")

    // ── Isla para los popups ─────────────────────────────────────────


    readonly property var islandRect: ({
        x: Math.round((pillWin.width - root.pillW) / 2),
        y: Theme.barAtBottom ? pillWin.height - root.pillH - root.edgeGap : root.edgeGap,
        w: root.pillW, h: root.pillH, r: 18
    })
    function reportIsland() {
        if (root.screenName === "" || pillWin.width <= 0 || pillWin.height <= 0) return
        IslandState.report(root.screenName, "center", root.islandRect)
    }
    onIslandRectChanged: root.reportIsland()

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: { if (!root.keepVisible) root.applyHidden(true) }
    }


    // ── Pager ──
    property string basePage: "main"
    property bool wsOverride: false
    readonly property int pageIndex: root.wsOverride ? -1 : (root.basePage === "media" ? 1 : 0)
    property real pagePos: 0
    property bool dragging: false
    property real dragX: 0
    property real wheelAcc: 0
    readonly property real dragRange: 140
    readonly property real swipeThreshold: 44
    readonly property bool swipeEnabled: !root.dashboardOpenHere && root.menuKind === ""

    onPageIndexChanged: root.pagePos = root.pageIndex
    Behavior on pagePos {
        enabled: !root.dragging
        NumberAnimation { duration: Theme.animDuration(360); easing.type: Easing.OutCubic }
    }

    function pageOffset(i) { return (i - root.pagePos) * 44 }
    function pageOpacity(i) { return Math.max(0, 1 - Math.abs(i - root.pagePos) * 1.4) }

    function minPos() {
        if (root.pageIndex === 1) return 0
        return -1
    }
    function maxPos() {
        if (root.pageIndex === -1) return root.basePage === "media" ? 1 : 0
        return 1
    }

    function dragMove(dx) {
        root.dragX = dx
        const p = root.pageIndex - dx / root.dragRange
        root.pagePos = Math.max(root.minPos(), Math.min(root.maxPos(), p))
    }

    function finishSwipe() {
        const dx = root.dragX
        root.dragging = false
        root.dragX = 0
        if (dx <= -root.swipeThreshold) root.swipe(-1)
        else if (dx >= root.swipeThreshold) root.swipe(1)
        root.pagePos = root.pageIndex
    }

    function swipe(dir) {
        if (dir < 0) {
            if (root.wsOverride) root.wsOverride = false
            else if (root.basePage === "main") root.basePage = "media"
        } else {
            if (root.wsOverride) return
            if (root.basePage === "media") root.basePage = "main"
            else root.showWorkspaces()
        }
    }

    // ── Workspaces temporales ──
    readonly property int activeWsId: WM.activeWorkspaceId(root.screenName)
    property int lastWsId: -999

    function showWorkspaces() {
        root.wsOverride = true
        wsTimer.restart()
    }

    onActiveWsIdChanged: {
        if (root.lastWsId !== -999 && root.activeWsId !== root.lastWsId
            && root.activeWsId !== -999 && !root.suppressed && !root.dashboardOpenHere)
            root.showWorkspaces()
        root.lastWsId = root.activeWsId
    }

    Timer {
        id: wsTimer
        interval: 2500
        onTriggered: {
            if (surfaceHover.hovered || root.dragging) wsTimer.restart()
            else root.wsOverride = false
        }
    }

    Timer {
        id: wheelCool
        interval: 450
    }

    // ── Medidas ─────────────────────────────────────────────────────


    readonly property int edgeGap: Theme.pillEdgeGap
    readonly property int peek: 4
    readonly property real ps: Theme.pillScale
    readonly property int mainW: Math.round(row.implicitWidth * root.ps) + 16
    readonly property int mediaW: Math.round(mediaPage.implicitWidth * root.ps) + 16
    readonly property int wsW: Math.max(112, Math.round(wsPage.width * root.ps) + 16)
    readonly property int pillW: root.pageIndex === 1 ? root.mediaW
                               : (root.pageIndex === -1 ? root.wsW : root.mainW)
    readonly property int pillH: Theme.pillHeight
    readonly property int triggerH: 6
    readonly property int notifWidth: 400
    readonly property int taskbarWidth: 260
    readonly property int clearance: 5

    // ── Espacio que las ventanas NO deben invadir ────────────────────


    readonly property int reserveZone: AppState.pillAutoHide
        ? Math.max(0, root.triggerH + root.clearance - AppState.gapsOut)
        : root.edgeGap + root.pillH


    property real mainWA: root.mainW
    property real mediaWA: root.mediaW
    property real wsWA: root.wsW
    Behavior on mainWA { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on mediaWA { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on wsWA { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    readonly property real pillWAnim: root.pagePos < 0
        ? root.mainWA + (root.wsWA - root.mainWA) * (-root.pagePos)
        : root.mainWA + (root.mediaWA - root.mainWA) * root.pagePos


    property real dockW: dashboard.fullWidth
    property real dockH: dashboard.fullHeight


    Behavior on dockW { enabled: surface.progress > 0.02; NumberAnimation { duration: Motion.dur(340); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsSlow } }
    Behavior on dockH { enabled: surface.progress > 0.02; NumberAnimation { duration: Motion.dur(340); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsSlow } }


    PillTray {
        id: sideTray
        targetScreen: root.targetScreen
        edgeGap: root.edgeGap
        pillH: root.pillH
        peek: root.peek
        syncedHidden: root.hiddenHere
        popupOpen: root.popupOpen
        onTrayMenuOpened: { root.closeTaskbarMenu(); root.trayMenuOpened() }
    }


    PanelWindow {
        id: reserveWin

        screen: root.targetScreen
        anchors {
            top: !Theme.barAtBottom
            bottom: Theme.barAtBottom
            left: true
            right: true
        }
        implicitHeight: Math.max(1, root.reserveZone)
        color: "transparent"
        visible: root.reserveZone > 0

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "oozeshell-pill-reserve"
        exclusiveZone: root.reserveZone
        mask: Region {}
    }

    PanelWindow {
        id: pillWin

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: !root.suppressed

        WlrLayershell.layer: WM.islandLayer
        WlrLayershell.namespace: "oozeshell-pill"
        exclusiveZone: -1


        mask: Region {
            item: surfaceMask
            Region { item: outsideCatcher }
            Region { item: trigger }
        }


        WlrLayershell.keyboardFocus: (root.dashboardOpenHere || root.menuKind !== "")
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Connections {
            target: root
            function onDashboardOpenHereChanged() {
                if (root.dashboardOpenHere) keyCatcher.forceActiveFocus()
            }
            function onMenuKindChanged() {
                if (root.menuKind !== "") keyCatcher.forceActiveFocus()
            }
        }


        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (root.menuKind !== "" && !root.dashboardOpenHere) {
                    if (event.key === Qt.Key_Escape) {
                        root.closeMenu()
                        event.accepted = true
                    }
                    return
                }
                if (!root.dashboardOpenHere) return
                if (event.key === Qt.Key_Escape) {
                    AppState.closeDashboard()
                    event.accepted = true
                } else if (dashboard.handleKey(event.key, event.modifiers)) {

                    event.accepted = true
                }
            }
        }


        Item {
            id: outsideCatcher
            readonly property bool on: root.dashboardOpenHere || root.menuKind !== ""
            width: on ? parent.width : 0
            height: on ? parent.height : 0
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.closeAll()
            }
        }


        Item {
            id: surfaceMask
            readonly property bool gone: AppState.pillAutoHide && root.hiddenHere
                && !root.dashboardOpenHere && root.menuKind === "" && surface.hideT > 0.98
            x: surface.x
            y: surface.y
            width: gone ? 0 : surface.width
            height: gone ? 0 : surface.height
        }


        Item {
            id: trigger
            readonly property bool armed: AppState.pillAutoHide && root.hiddenHere
            readonly property bool hovered: triggerHover.hovered
            width: Math.max(360, root.pillW)
            height: armed ? root.triggerH
                  : (AppState.pillAutoHide ? Math.max(root.triggerH, root.edgeGap + 2) : 0)
            x: Math.round((parent.width - width) / 2)
            y: Theme.barAtBottom ? parent.height - height : 0
            HoverHandler { id: triggerHover }
        }


        Item {
            id: surface

            readonly property bool open: root.dashboardOpenHere


            property real progress: open ? 1 : 0


            Behavior on progress {
                NumberAnimation {
                    duration: Theme.animDuration(surface.open ? (Theme.cozy ? 380 : 420) : 280)
                    easing.type: surface.open ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: Theme.cozy ? 0.45 : 0.9
                }
            }


            function stage(a, b) {
                return Math.max(0, Math.min(1, (surface.progress - a) / (b - a)))
            }
            function ease(t) { return t * t * (3 - 2 * t) }


            property real mp: root.menuKind !== "" ? 1 : 0
            Behavior on mp {
                NumberAnimation {
                    duration: Theme.animDuration(root.menuKind !== "" ? 300 : 220)
                    easing.type: Easing.OutCubic
                }
            }
            function stageM(a, b) { return Math.max(0, Math.min(1, (surface.mp - a) / (b - a))) }


            readonly property real pillT: Math.min(1 - ease(stage(0.0, 0.30)), 1 - ease(stageM(0.0, 0.35)))
            readonly property real dashT: ease(stage(0.38, 0.85))
            readonly property real menuT: ease(stageM(0.35, 0.9))


            readonly property real menuW: Math.max(root.pillW,
                root.lastKind === "notif" ? root.notifWidth : root.taskbarWidth)
            readonly property real menuH: Math.max(root.pillH, Math.round(
                root.lastKind === "notif" ? notifList.implicitHeight : taskbarList.implicitHeight))


            property real hideT: (root.hiddenHere && !open && root.menuKind === "") ? 1 : 0
            Behavior on hideT { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
            readonly property real slide: hideT * (root.pillH + root.edgeGap - root.peek)


            width: Math.round((root.pillWAnim + (root.dockW - root.pillWAnim) * progress
                              + (surface.menuW - root.pillWAnim) * mp) / 2) * 2
            height: Math.round(root.pillH + (root.dockH - root.pillH) * progress
                              + (surface.menuH - root.pillH) * mp)

            x: Math.round((parent.width - width) / 2)
            y: Math.round(Theme.barAtBottom
                ? parent.height - height - root.edgeGap + slide
                : root.edgeGap - slide)

            clip: true

            SkinRect {
                anchors.fill: parent


                radius: Theme.cozy ? 4 : (18 * root.ps + (22 - 18 * root.ps) * Math.min(1, surface.progress + surface.mp))
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 3
            }


            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }


            HoverHandler {
                id: surfaceHover
                onHoveredChanged: {
                    root.noteHover(hovered)
                    if (!hovered && root.wsOverride) wsTimer.restart()
                }
            }

            // ── Gestos ──
            DragHandler {
                id: swipeDrag
                target: null
                enabled: root.swipeEnabled
                acceptedButtons: Qt.LeftButton
                xAxis.enabled: true
                yAxis.enabled: false
                dragThreshold: 8
                onActiveChanged: {
                    if (active) { root.dragging = true; root.dragX = 0 }
                    else if (root.dragging) root.finishSwipe()
                }
                onTranslationChanged: { if (active) root.dragMove(translation.x) }
            }

            WheelHandler {
                orientation: Qt.Horizontal
                acceptedDevices: PointerDevice.TouchPad
                enabled: root.swipeEnabled
                onWheel: event => {
                    if (wheelCool.running) return
                    root.wheelAcc += event.angleDelta.x
                    if (Math.abs(root.wheelAcc) < 120) return
                    root.swipe(root.wheelAcc > 0 ? 1 : -1)
                    root.wheelAcc = 0
                    wheelCool.restart()
                }
            }

            // ── Estado píldora ──────────────────────────────


            Item {
                id: pillContent
                width: root.pillW
                height: root.pillH
                x: Math.round((surface.width - width) / 2)
                y: Theme.barAtBottom ? surface.height - height : 0

                opacity: surface.pillT
                visible: opacity > 0.01
                enabled: !surface.open && root.menuKind === ""
                scale: Theme.cozy ? 1.0 : 1 - 0.08 * (1 - surface.pillT)
                transformOrigin: Item.Center

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.pageOffset(0)
                    opacity: root.pageOpacity(0)
                    visible: opacity > 0.01
                    enabled: root.pageIndex === 0
                    spacing: 4


                    scale: root.ps
                    transformOrigin: Item.Center

                    PillNotifications {
                        active: NotificationsBackend.centerOpen
                        onClicked: root.notificationButtonClicked(root.targetScreen)
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignCenter
                        radius: 1
                        color: Theme.primary
                        opacity: 0.25
                    }

                    PillClock {
                        active: root.dashboardOpenHere
                        onClicked: AppState.toggleDashboard(AppState.dashboardSection || "power", root.screenName)
                        onRightClicked: AppState.toggleDashboard("calendar", root.screenName)
                    }

                    Rectangle {
                        visible: pillTaskbar.count > 0
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignCenter
                        radius: 1
                        color: Theme.primary
                        opacity: 0.25
                    }

                    PillTaskbar {
                        id: pillTaskbar
                        visible: pillTaskbar.count > 0
                        targetScreen: root.targetScreen
                        onMenuRequested: item => root.openTaskbarMenu(item)
                    }
                }

                PillMedia {
                    id: mediaPage
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.pageOffset(1)
                    opacity: root.pageOpacity(1)
                    visible: opacity > 0.01
                    enabled: root.pageIndex === 1
                    scale: root.ps
                    transformOrigin: Item.Center
                    active: root.pageIndex === 1 && !root.dashboardOpenHere
                    onOpenRequested: AppState.toggleDashboard("mpris", root.screenName)
                }

                PillWorkspaces {
                    id: wsPage
                    screenName: root.screenName
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.pageOffset(-1)
                    opacity: root.pageOpacity(-1)
                    visible: opacity > 0.01
                    enabled: root.pageIndex === -1
                    scale: root.ps
                    transformOrigin: Item.Center
                }
            }

            // ── Estado dock ─────────────────────────────────


            Dashboard {
                id: dashboard


                width: Math.round(dashboard.fullWidth)
                height: Math.round(dashboard.fullHeight)
                x: Math.round((surface.width - width) / 2)
                y: Math.round((Theme.barAtBottom ? surface.height - height : 0)
                   + (Theme.barAtBottom ? 1 : -1) * 10 * (1 - surface.dashT))

                screenName: root.screenName
                open: surface.open


                keepLoaded: surface.progress > 0.001


                warm: root.warm

                opacity: surface.dashT
                visible: opacity > 0.01
                enabled: surface.open
                scale: Theme.cozy ? 1.0 : 0.965 + 0.035 * surface.dashT
                transformOrigin: Theme.barAtBottom ? Item.Bottom : Item.Top

                onRequestNetwork: root.requestNetwork(root.targetScreen)
                onRequestBluetooth: root.requestBluetooth(root.targetScreen)
                onRequestAppearance: root.requestAppearance(root.targetScreen)
                onRequestWalls: root.requestWalls(root.targetScreen)
                onRequestAdvancedSettings: root.requestAdvancedSettings(root.targetScreen)
            }

            // ── Estado notificaciones ───────────────────────


            NotifList {
                id: notifList
                width: root.notifWidth
                height: implicitHeight
                x: Math.round((surface.width - width) / 2)
                y: Theme.barAtBottom ? surface.height - height : 0
                showClose: true
                maxListHeight: Math.max(160, pillWin.height - root.edgeGap * 2 - root.pillH - 300)
                listActive: root.notifOpenHere || (root.lastKind === "notif" && surface.mp > 0.001)
                entriesAnimated: root.notifOpenHere && surface.mp >= 0.999
                onCloseRequested: root.closeMenu()

                opacity: root.lastKind === "notif" ? surface.menuT : 0
                visible: opacity > 0.01
                enabled: root.notifOpenHere
                transform: Translate { y: (Theme.barAtBottom ? 1 : -1) * 8 * (1 - surface.menuT) }
            }

            // ── Estado taskbar (lista de ventanas) ──────────
            TaskbarList {
                id: taskbarList
                width: root.taskbarWidth
                height: implicitHeight
                x: Math.round((surface.width - width) / 2)
                y: Theme.barAtBottom ? surface.height - height : 0
                showClose: true
                windows: pillTaskbar.windows
                maxListHeight: Math.max(120, Math.min(420, pillWin.height - root.pillH - root.edgeGap * 2 - 120))
                onCloseRequested: root.closeMenu()

                opacity: root.lastKind === "taskbar" ? surface.menuT : 0
                visible: opacity > 0.01
                enabled: root.taskbarMenuOpen
                transform: Translate { y: (Theme.barAtBottom ? 1 : -1) * 8 * (1 - surface.menuT) }
            }
        }
    }


    FrameAnimation {
        running: Quickshell.env("OOZE_FRAME_DEBUG") === "1" && surface.progress > 0.001
        onTriggered: {
            if (frameTime > 0.022)
                console.log("[ooze " + (Date.now() % 100000) + "] frame largo:", Math.round(frameTime * 1000), "ms · sección:", AppState.dashboardSection, "· progreso:", surface.progress.toFixed(2))
        }
    }
}
