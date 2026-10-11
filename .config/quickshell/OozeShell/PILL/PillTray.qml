// PillTray.qml — PILL

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../TRAY"
import "../BATTERY"
import "../PRIVACY"


Item {
    id: root

    property var targetScreen
    readonly property string screenName: targetScreen ? targetScreen.name : ""


    property int edgeGap: Theme.pillEdgeGap
    property int pillH: Theme.pillHeight


    readonly property real ps: Theme.pillScale
    function px(v) { return Math.round(v * root.ps) }
    readonly property real surfaceW: content.implicitWidth + 16
    property int peek: 4

    property bool syncedHidden: false
    readonly property bool sync: AppState.pillTraySync

    property bool hiddenOwn: false
    readonly property bool hidden: root.sync ? root.syncedHidden : root.hiddenOwn
    property bool popupOpen: false

    property int menuWidth: 250


    readonly property bool suppressed: FullscreenState.isOn(targetScreen)
    onSuppressedChanged: { if (root.suppressed) { root.closeTrayMenu(); root.hideTip() } }


    signal trayMenuOpened()

    readonly property bool showTray: AppState.trayVisible && tray.count > 0
    readonly property bool showBattery: Theme.batteryEnabled && BatteryBackend.available

    readonly property bool showPrivacy: privacy.present
    readonly property bool hasContent: root.showTray || root.showBattery || root.showPrivacy


    readonly property bool keepVisible:
        surfaceHover.hovered || triggerHover.hovered || root.trayMenuOpen

    readonly property bool ownKeep: !AppState.pillAutoHide || root.keepVisible
    onOwnKeepChanged: {
        if (root.ownKeep) { ownHideTimer.stop(); root.hiddenOwn = false }
        else ownHideTimer.restart()
    }
    Component.onCompleted: {
        if (!root.ownKeep) ownHideTimer.restart()
        root.reportIsland()
    }
    Component.onDestruction: IslandState.clearPill(root.screenName, "right")

    // ── Isla para el menú de la bandeja ──────────────────────────────

    readonly property var islandRect: ({
        x: win.width - root.surfaceW - root.edgeGap,
        y: Theme.barAtBottom ? win.height - root.pillH - root.edgeGap : root.edgeGap,
        w: root.surfaceW, h: root.pillH, r: 16
    })
    function reportIsland() {
        if (root.screenName === "" || win.width <= 0 || win.height <= 0 || !root.hasContent) {
            IslandState.clear(root.screenName, "right")
            return
        }
        IslandState.report(root.screenName, "right", root.islandRect)
    }
    onIslandRectChanged: root.reportIsland()
    onHasContentChanged: root.reportIsland()
    Timer {
        id: ownHideTimer
        interval: 1500
        onTriggered: { if (!root.ownKeep) root.hiddenOwn = true }
    }

    // ── Menú de la bandeja (TRAY/TrayMenuList.qml, dentro de la pastilla) ──
    property bool trayMenuOpen: false
    property var menuItem: null
    function closeTrayMenu() { root.trayMenuOpen = false }
    function openTrayMenu(iconItem, entry) {
        if (root.trayMenuOpen && root.menuItem === entry) { root.closeTrayMenu(); return }
        root.hideTip()
        root.trayMenuOpened()
        root.menuItem = entry
        root.trayMenuOpen = true
    }
    onPopupOpenChanged: { if (root.popupOpen) { root.closeTrayMenu(); root.hideTip() } }
    onHiddenChanged: { if (root.hidden) { root.closeTrayMenu(); root.hideTip() } }

    readonly property bool dashboardOpen: AppState.dashboardOpen
    onDashboardOpenChanged: { if (root.dashboardOpen) root.closeTrayMenu() }

    // ── Tooltip sencillo (debajo de la pastilla) ────────────────────
    property var tipTarget: null
    property string tipText: ""
    property bool tipShown: false
    function tipEnter(item) {
        tipHide.stop()
        tipTarget = item
        tipText = String(item.tip ?? "")
        if (!tipShown) tipShow.restart()
    }
    function tipLeave(item) {
        if (tipTarget !== item) return
        tipShow.stop()
        tipHide.restart()
    }
    function hideTip() { tipShow.stop(); tipHide.stop(); tipShown = false }
    Timer { id: tipShow; interval: 500; onTriggered: root.tipShown = true }
    Timer { id: tipHide; interval: 150; onTriggered: root.tipShown = false }

    readonly property string batteryTip: {
        if (!BatteryBackend.available) return ""
        const pct = Math.round(BatteryBackend.percentage * 100) + "%"
        const state = BatteryBackend.fullyCharged ? Translations.t("batteryFull")
                    : BatteryBackend.charging     ? Translations.t("batteryCharging")
                                                   : Translations.t("batteryDischarging")
        const secs = BatteryBackend.charging ? BatteryBackend.timeToFull : BatteryBackend.timeToEmpty
        const time = BatteryBackend.formatSecs(secs)
        const label = BatteryBackend.charging ? Translations.t("batteryTimeToFull")
                                               : Translations.t("batteryTimeToEmpty")
        return pct + " — " + state + (time !== "" ? ("\n" + label + " " + time) : "")
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: root.hasContent && !Theme.barRebuilding && !root.suppressed

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "oozeshell-pill-tray"
        exclusiveZone: -1


        mask: Region {
            item: surfaceMask
            Region { item: outsideCatcher }
            Region { item: trigger }
        }


        WlrLayershell.keyboardFocus: root.trayMenuOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Connections {
            target: root
            function onTrayMenuOpenChanged() {
                if (root.trayMenuOpen) keyCatcher.forceActiveFocus()
            }
        }


        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (!root.trayMenuOpen) return
                if (event.key === Qt.Key_Escape) {
                    root.closeTrayMenu()
                    event.accepted = true
                }
            }
        }


        Item {
            id: outsideCatcher
            width: root.trayMenuOpen ? parent.width : 0
            height: root.trayMenuOpen ? parent.height : 0
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.closeTrayMenu()
            }
        }

        Item {
            id: surfaceMask
            readonly property bool gone: root.hidden && !root.keepVisible
            x: surface.x
            y: surface.y
            width: gone ? 0 : surface.width
            height: gone ? 0 : surface.height
        }


        Item {
            id: trigger
            width: Math.max(120, root.surfaceW)
            height: root.hidden ? 6
                  : (AppState.pillAutoHide ? Math.max(6, root.edgeGap + 2) : 0)
            x: parent.width - width - root.edgeGap
            y: Theme.barAtBottom ? parent.height - height : 0
            HoverHandler { id: triggerHover }
        }

        Item {
            id: surface


            property real progress: root.trayMenuOpen ? 1 : 0
            Behavior on progress {
                NumberAnimation {
                    duration: Theme.animDuration(root.trayMenuOpen ? 300 : 220)
                    easing.type: Easing.OutCubic
                }
            }
            function ease(t) { return t * t * (3 - 2 * t) }
            function stage(a, b) { return Math.max(0, Math.min(1, (surface.progress - a) / (b - a))) }

            readonly property real pillT: 1 - ease(stage(0.0, 0.35))
            readonly property real menuT: ease(stage(0.35, 0.9))


            readonly property real menuW: Math.max(root.menuWidth, root.surfaceW)
            readonly property real menuH: Math.max(root.pillH, Math.round(menuList.implicitHeight))


            property real baseW: root.surfaceW
            Behavior on baseW { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }


            width: Math.round((surface.baseW + (surface.menuW - surface.baseW) * surface.progress) / 2) * 2
            height: Math.round(root.pillH + (surface.menuH - root.pillH) * surface.progress)


            property real hideT: (root.hidden && !root.trayMenuOpen) ? 1 : 0
            Behavior on hideT { NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic } }
            readonly property real slide: hideT * (root.pillH + root.edgeGap - root.peek)


            x: parent.width - width - root.edgeGap
            y: Math.round(Theme.barAtBottom
                ? parent.height - height - root.edgeGap + slide
                : root.edgeGap - slide)

            clip: true

            SkinRect {
                anchors.fill: parent
                radius: Theme.cozy ? 4 : (16 + 6 * Math.min(1, surface.progress))
                color: Theme.bg
                inkColor: Theme.ink
                raised: Theme.cozy
                depth: 2
            }


            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }


            HoverHandler { id: surfaceHover }

            RowLayout {
                id: content


                x: Math.round(surface.width - surface.baseW + (surface.baseW - width) / 2)
                y: Math.round((Theme.barAtBottom ? surface.height - root.pillH : 0) + (root.pillH - height) / 2)
                spacing: root.px(4)
                opacity: surface.pillT
                visible: opacity > 0.01
                enabled: !root.trayMenuOpen


                Privacy {
                    id: privacy
                    iconSize: root.px(16)
                    visible: privacy.present
                    onTipEnter: item => root.tipEnter(item)
                    onTipLeave: item => root.tipLeave(item)
                }

                Rectangle {
                    visible: root.showPrivacy && (root.showTray || root.showBattery)
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.px(16)
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                Tray {
                    id: tray
                    visible: AppState.trayVisible && tray.count > 0
                    iconSize: root.px(16)
                    uiScale: root.ps
                    snapSizes: true
                    renderScale: 1
                    activeItem: root.trayMenuOpen ? root.menuItem : null
                    onTipEnter: item => root.tipEnter(item)
                    onTipLeave: item => root.tipLeave(item)
                    onMenuRequested: (iconItem, entry) => root.openTrayMenu(iconItem, entry)
                }

                Rectangle {
                    visible: root.showTray && root.showBattery
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.px(16)
                    Layout.alignment: Qt.AlignCenter
                    radius: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                SkinRect {
                    id: batteryBtn
                    visible: root.showBattery
                    readonly property string tip: root.batteryTip

                    Layout.preferredHeight: root.px(28)
                    Layout.preferredWidth: batteryRow.implicitWidth + root.px(16)
                    radius: root.px(10)
                    color: bm.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    RowLayout {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: root.px(5)
                        BatteryIcon {
                            Layout.alignment: Qt.AlignVCenter
                            percentage: BatteryBackend.percentage
                            charging: BatteryBackend.charging
                            full: BatteryBackend.fullyCharged
                            low: BatteryBackend.isLow
                            iconHeight: Math.max(10, root.px(Theme.fs(12)))
                        }
                        Text {
                            text: Math.round(BatteryBackend.percentage * 100) + "%"
                            color: BatteryBackend.isLow ? Theme.error : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(6, root.px(Theme.fs(12)))
                        }
                    }
                    MouseArea {
                        id: bm
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.tipEnter(batteryBtn)
                        onExited: root.tipLeave(batteryBtn)
                    }
                }
            }

            // ── Lista del menú ──────────────────────────────────────────


            TrayMenuList {
                id: menuList
                width: surface.menuW
                height: implicitHeight
                x: surface.width - width
                y: Theme.barAtBottom ? surface.height - height : 0
                trayItem: root.menuItem
                showClose: true
                maxListHeight: Math.max(120, Math.min(420, win.height - root.pillH - root.edgeGap * 2 - 120))
                onCloseRequested: root.closeTrayMenu()

                opacity: surface.menuT
                visible: opacity > 0.01
                enabled: root.trayMenuOpen

                transform: Translate { y: (Theme.barAtBottom ? 1 : -1) * 8 * (1 - surface.menuT) }
            }
        }


        Rectangle {
            id: tipBox
            visible: opacity > 0.01
            opacity: (root.tipShown && !root.trayMenuOpen && !root.popupOpen && !root.hidden
                      && root.tipTarget !== null && root.tipText !== "") ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

            width: tipLabel.implicitWidth + 20
            height: tipLabel.implicitHeight + 14
            radius: 10
            color: Theme.bg
            border.width: Theme.bw1
            border.color: Theme.edge

            x: Math.max(6, Math.min(parent.width - width - 6,
                root.tipTarget ? root.tipTarget.mapToItem(null, root.tipTarget.width / 2, 0).x - width / 2
                               : 0))
            y: Theme.barAtBottom ? surface.y - height - 6 : surface.y + surface.height + 6

            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: root.tipText
                color: Theme.text
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
