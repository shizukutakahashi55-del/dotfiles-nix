// BarHost — base común de las tres islas de la barra (LEFT / CENTER / RIGHT).

import Quickshell
import QtQuick

import "../../../COMMON"
import "../../Tray"
import "../../Taskbar"

Item {
  id: host

  // ─── Identidad ─────────────────────────────────────────────────
  property string side: "left"
  property var targetScreen
  readonly property string screenName: targetScreen ? targetScreen.name : ""

  // ─── Señales hacia Bar.qml / shell.qml ─────────────────────────
  signal mprisButtonClicked()
  signal powerButtonClicked()
  signal notificationButtonClicked()
  signal clockRightClicked()
  signal audioButtonClicked()
  signal menuButtonClicked()
  signal trayMenuOpened()

  // ─── Estado que llega desde shell.qml ──────────────────────────
  property bool mprisOpen: false
  property bool notifyOpen: false
  property bool agendaOpen: false
  property bool audioOpen: false
  property bool menuOpen: false
  property bool popupOpen: false
  property bool wallpaperChanging: false

  property bool hideOnFullscreen: true
  property bool hideOnWallpaperChange: true

  readonly property bool suppressed:
    (hideOnFullscreen && FullscreenState.isOn(targetScreen))
    || (hideOnWallpaperChange && wallpaperChanging)

  // ─── Geometría que completa cada isla ──────────────────────────
  property Item pillItem: null
  property point panelOrigin: Qt.point(0, 0)
  property bool occupied: false
  property bool pillHovered: false
  readonly property bool shown: host.occupied && Theme.barDrawn
  readonly property bool live: host.shown && !host.suppressed
  property real othersHeight: 0
  property real spanX: 0
  property real spanW: 0
  property var islandRect: null

  // ─── Reservas de la barra vertical ─────────────────────────────
  property real centerHeight: 0
  property real topReserve: 0
  property real bottomReserve: 0

  readonly property real verticalRoom: {
    const h = host.targetScreen ? host.targetScreen.height : 1080
    if (host.side === "center")
      return h - host.topReserve - host.bottomReserve - 16 - 14 * Theme.barScale
    return h / 2 - host.centerHeight / 2 - 8 - 6 - Theme.barEdge - 14 * Theme.barScale
  }

  // ─── Coordenadas de pantalla ───────────────────────────────────
  function screenPointOf(item) {
    const p = item.mapToItem(null, item.width / 2, item.height / 2)
    return Qt.point(host.panelOrigin.x + p.x, host.panelOrigin.y + p.y)
  }

  function alongCenterOf(item) {
    const p = host.screenPointOf(item)
    return Theme.barVertical ? p.y : p.x
  }

  // ─── Isla en IslandState ───────────────────────────────────────
  function publishIsland() {
    if (host.screenName === "") return
    if (host.islandRect && host.shown) IslandState.report(host.screenName, host.side, host.islandRect)
    else IslandState.clear(host.screenName, host.side)
  }
  onIslandRectChanged: publishIsland()
  onShownChanged: publishIsland()
  Connections {
    target: IslandState
    function onRefreshRequested() { host.publishIsland() }
  }
  Component.onCompleted: publishIsland()

  // ─── Tooltip compartido ────────────────────────────────────────
  property var tipTarget: null
  property real tipCenterX: 0
  property real tipCenterY: 0
  property bool tipShown: false
  property string tipText: ""

  readonly property string liveTip: tipTarget ? String(tipTarget.tip ?? "") : ""
  onLiveTipChanged: { if (liveTip !== "") tipText = liveTip }

  readonly property bool calendarHere: BarCalendar.isOpen(host.screenName)
  readonly property bool tipAllowed: !popupOpen && !trayMenuOpen && !suppressed && !calendarHere
  readonly property bool tipOpen:
    tipShown && tipAllowed && tipTarget !== null && tipTarget.visible && tipText !== ""

  function tipEnter(item) {
    tipHideTimer.stop()
    tipTarget = item
    tipText = liveTip
    const c = item.mapToItem(null, item.width / 2, item.height / 2)
    tipCenterX = c.x
    tipCenterY = c.y
    if (!tipShown) tipShowTimer.restart()
  }

  function tipRefresh() {
    if (!tipTarget) return
    const c = tipTarget.mapToItem(null, tipTarget.width / 2, tipTarget.height / 2)
    tipCenterX = c.x
    tipCenterY = c.y
  }

  function tipLeave(item) {
    if (tipTarget !== item) return
    tipShowTimer.stop()
    tipHideTimer.restart()
  }

  Connections {
    target: host.pillItem
    function onWidthChanged() { Qt.callLater(host.tipRefresh) }
    function onXChanged() { Qt.callLater(host.tipRefresh) }
  }

  Timer { id: tipShowTimer; interval: 500; repeat: false; onTriggered: host.tipShown = true }
  Timer { id: tipHideTimer; interval: 150; repeat: false; onTriggered: host.tipShown = false }

  // ─── Menú de la bandeja ────────────────────────────────────────
  property bool trayMenuOpen: false
  property var trayMenuEntry: null

  function closeTrayMenu() { trayMenuOpen = false }

  function openTrayMenu(iconItem, entry) {
    if (trayMenuOpen && trayMenuEntry === entry) {
      closeTrayMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    host.trayMenuOpened()
    closeTaskbarMenu()
    trayMenuEntry = entry
    const p = host.screenPointOf(iconItem)
    trayMenu.anchorX = p.x
    trayMenu.anchorY = p.y
    trayMenuOpen = true
  }

  TrayMenu {
    id: trayMenu
    open: host.trayMenuOpen
    trayItem: host.trayMenuEntry
    targetScreen: host.screenName
    onCloseRequested: host.closeTrayMenu()
  }

  // ─── Menú del taskbar ──────────────────────────────────────────
  property bool taskbarMenuOpen: false
  property var taskbarWindows: []

  function closeTaskbarMenu() { taskbarMenuOpen = false }

  function openTaskbarMenu(iconItem) {
    if (taskbarMenuOpen) {
      closeTaskbarMenu()
      return
    }
    tipShown = false
    tipShowTimer.stop()
    host.trayMenuOpened()
    closeTrayMenu()
    const p = host.screenPointOf(iconItem)
    taskbarMenu.anchorX = p.x
    taskbarMenu.anchorY = p.y
    taskbarMenuOpen = true
  }

  TaskbarMenu {
    id: taskbarMenu
    open: host.taskbarMenuOpen
    windows: host.taskbarWindows
    targetScreen: host.screenName
    onCloseRequested: host.closeTaskbarMenu()
  }

  // ─── Cierres automáticos ───────────────────────────────────────
  onPopupOpenChanged: { if (popupOpen) { closeTrayMenu(); closeTaskbarMenu() } }
  onSuppressedChanged: {
    if (suppressed) {
      closeTrayMenu()
      closeTaskbarMenu()
      tipShown = false
      if (BarCalendar.isOpen(host.screenName)) BarCalendar.hide()
    }
  }
}
