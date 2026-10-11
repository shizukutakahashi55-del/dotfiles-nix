// shell.qml — SHELL
// OozeShell Wallpapers and More

import Quickshell
import Quickshell.Io
import QtQuick
import "./WALLS"
import "./NOTIFY"
import "./MPRIS"
import "./MONITOR"
import "./Keybinds"
import "./Launcher"
import "./QUICKBAR"
import "./PackageSearch"
import "./SCREENSHOT"
import "./LANG"
import "./APPEARANCE"
import "./SETTINGS"
import "./BAR"
import "./DOCK"
import "./MENU"
import "./COMMON"
import "./NETWORK"
import "./BLUETOOTH"
import "./AUDIO"
import "./CAPS"
import "./OVERVIEW"
import "./POWER"
import "./LOCK"
import "./PILL"
import "./AGENDA"
import "./CLIPBOARD"
import "./CAFFEINE"
import "./WIDGETS"

ShellRoot {
  id: root

  // ─── IPC ───

  IpcHandler {
    target: "corners"
    function toggle(): void { root.setScreenCorners(!root.screenCorners) }
    function set(on: bool): void { root.setScreenCorners(on) }
    function get(): bool { return root.screenCorners }
  }

  IpcHandler {
    target: "bar"
    function position(p: string): void { Theme.setBarPosition(p) }
    function togglePosition(): void {
      const flip = { top: "bottom", bottom: "top", left: "right", right: "left" }
      Theme.setBarPosition(flip[Theme.barPosition] ?? "top")
    }
    function floating(on: bool): void { Theme.setBarFloating(on) }
    function toggleFloating(): void { Theme.setBarFloating(!Theme.barFloatingPref) }

    function islands(on: bool): void { Theme.setIslandsEnabled(on) }
    function toggleIslands(): void { Theme.setIslandsEnabled(!Theme.islandsPref) }
    function pill(on: bool): void { Theme.setPillModeEnabled(on) }
    function togglePill(): void { Theme.setPillModeEnabled(!Theme.pillModePref) }
    function get(): string {
      return JSON.stringify({ position: Theme.barPosition, floating: Theme.barFloatingPref,
                              islands: Theme.islandsPref, pill: Theme.pillModePref })
    }
  }

  IpcHandler {
    target: "caffeine"
    function toggle(): void { CaffeineBackend.toggle() }
    function set(on: bool): void { CaffeineBackend.set(on) }
    function get(): bool { return CaffeineBackend.active }
  }

  IpcHandler {
    target: "monitor"

    function set(name: string): void { root.setMonitor(name) }

    function get(): string { return root.targetMonitor }
    function togglePicker(): void { root.togglePopup("monitor") }


    function list(): string {
      return Quickshell.screens.map(s => s.name).join(", ")
    }


    function current(): string { return root.resolveMonitor() }
  }

  IpcHandler {
    target: "lang"
    function set(code: string): void { root.setLang(code) }
    function get(): string { return root.currentLang }
    function togglePicker(): void { root.togglePopup("lang") }
    function list(): string {
      return Translations.availableLanguages.map(l => l.code + " (" + l.name + ")").join(", ")
    }
  }

  IpcHandler {
    target: "settings"
    function toggle(): void { root.togglePopup("advancedsettings") }
    function open(): void { root.openPopup("advancedsettings") }
    function close(): void { root.advancedSettingsOpen = false }
    function get(): string {
      return JSON.stringify({ font: Theme.fontLevel, bar: Theme.barLevel, window: Theme.windowLevel,
                              winW: Theme.settingsWinW, winH: Theme.settingsWinH })
    }
    function setUi(level: int): void { Theme.setInterfaceLevel(level) }
    function setLevel(kind: string, level: int): void { Theme.setLevel(kind, level) }
    function reset(): void { Theme.resetLevels() }
    function setWindow(w: int, h: int): void { Theme.setSettingsWinW(w); Theme.setSettingsWinH(h) }
    function resetWindow(): void { Theme.resetSettingsWin() }
  }

  IpcHandler {
    target: "theme"
    function mode(m: string): void { Theme.setThemeMode(m) }
    function toggle(): void { Theme.setThemeMode(Theme.themeMode === "dark" ? "light" : "dark") }
    function cycle(): void {
      const order = ["dark", "light", "colorful"]
      Theme.setThemeMode(order[(order.indexOf(Theme.themeMode) + 1) % order.length])
    }
    function get(): string { return Theme.schemeMode }

    function style(s: string): void { Theme.setUiStyle(s) }
    function styleGet(): string { return Theme.uiStyle }

    function font(name: string): void { Theme.setFontPref(name) }
    function fontGet(): string { return Theme.fontFamily }

    function softfont(name: string): void { Theme.setSoftFont(name) }
    function softfontGet(): string { return Theme.softFamily }
    function pixelfont(name: string): void { Theme.setPixelFont(name) }
    function pixelfontGet(): string { return Theme.pixelFamily }


    function fonts(): string {
      return "texto=" + Theme.fontFamily + " | títulos=" + Theme.titleFamily
        + " | íconos=" + Theme.monoFamily + " | pixel=" + Theme.pixelFamily
        + " | Nunito=" + (Theme.hasFont("Nunito") ? "sí" : "NO")
        + " | M PLUS Rounded 1c=" + (Theme.hasFont("M PLUS Rounded 1c") ? "sí" : "NO")
        + " | rescatadas=" + Theme.rescuedCount + " | " + Theme.fontReport
    }
    function fontsrefresh(): string { Theme.refreshFonts(); return "releyendo fuentes…" }


    // ── CoOzey ──  (`theme style cozy` lo activa)


    function cozy(mode: string): void { Theme.enableCozy(mode === "dark" ? true : mode === "light" ? false : null) }
    function palette(name: string): void { Theme.setPaletteByName(name) }
    function cozywarm(n: int): void { Theme.setCozyWarm(n) }
  }

  IpcHandler {
    target: "appearance"
    function toggle(): void { root.togglePopup("appearance") }
    function get(): string { return JSON.stringify(root.appearance) }

    function set(key: string, value: string): void {
      if (key === "layout") { root.setLayout(value); return }
      if (key === "animProfile") { root.setAnimProfile(value); return }
      if (key === "blurEnabled" || key === "blurOptimized" || key === "animationsEnabled" || key === "shadowEnabled") {
        root.setAppearanceValue(key, (value === "true" || value === "1"))
      } else {
        root.setAppearanceValue(key, parseFloat(value))
      }
    }
  }

  IpcHandler {
    target: "toggleWalls"
    function handle() { root.wallsOpen = !root.wallsOpen }
  }

  IpcHandler {
    target: "notify"
    function toggle(): void { root.togglePopup("notify") }

    function show(text: string): void { NotificationsBackend.pushLocal("OozeShell", text) }
    function toggleDnd(): void { NotificationsBackend.toggleDnd() }
    function enableDnd(): void { NotificationsBackend.dnd = true }
    function disableDnd(): void { NotificationsBackend.dnd = false }
    function isDnd(): bool { return NotificationsBackend.dnd }
    function clear(): void { NotificationsBackend.clearAll() }
    function state(): string {
      return JSON.stringify({ count: NotificationsBackend.count, dnd: NotificationsBackend.dnd })
    }
  }

  IpcHandler {
    target: "agenda"
    function toggle(): void {
      if (Theme.pillMode) AppState.toggleDashboard("calendar", root.focusedMonitor)
      else root.togglePopup("agenda")
    }
    function open(): void {
      if (Theme.pillMode) AppState.openDashboard("calendar", root.focusedMonitor)
      else root.openPopup("agenda")
    }
    function close(): void {
      if (Theme.pillMode) AppState.closeDashboard()
      else root.agendaOpen = false
    }
  }

  IpcHandler {
    target: "performance"
    function toggle(): void { Theme.setPerformanceMode(!Theme.performanceMode) }
    function set(on: bool): void { Theme.setPerformanceMode(on) }
    function get(): bool { return Theme.performanceMode }
  }

  IpcHandler {
    target: "keybinds"

    function toggle(): void { root.togglePopup("keybinds") }
  }

  IpcHandler {
    target: "keyboardlayout"
    function next(): void { KeyboardLayout.next() }
  }

  IpcHandler {
    target: "menu"
    function toggle(): void {
      if (Theme.pillMode) AppState.toggleDashboard("quickaccess", root.focusedMonitor)
      else root.togglePopup("menu")
    }
  }

  IpcHandler {
    target: "network"
    function toggle(): void { root.togglePopup("network") }
  }

  IpcHandler {
    target: "bluetooth"
    function toggle(): void { root.togglePopup("bluetooth") }
  }

  IpcHandler {
    target: "audio"
    function toggle(): void {
      if (Theme.pillMode) AppState.toggleDashboard("audio", root.focusedMonitor)
      else root.togglePopup("audio")
    }
    function raise(): void { AudioBackend.stepVolume(0.05) }
    function lower(): void { AudioBackend.stepVolume(-0.05) }
    function mute(): void { AudioBackend.toggleMuteOsd() }
    function micToggle(): void { AudioBackend.toggleMicMuteOsd() }
    function micRaise(): void { AudioBackend.stepMicVolume(0.05) }
    function micLower(): void { AudioBackend.stepMicVolume(-0.05) }
  }

  IpcHandler {
    target: "caps"
    function show(on: bool): void { capsOsd.show(on) }
  }

  IpcHandler {
    target: "layoutosd"
    function show(name: string): void { layoutOsd.show(name, KeyboardLayout.labelFor(name)) }
  }

  IpcHandler {
    target: "osd"
    function show(icon: string, title: string, subtitle: string, active: bool): void {
      toastOsd.show(icon, title, subtitle, active)
    }
  }

  IpcHandler {
    target: "clipboard"
    function toggle(): void { clipboardHistory.toggle() }
    function open(): void { clipboardHistory.open() }
    function close(): void { clipboardHistory.close() }
  }

  IpcHandler {
    target: "overview"


    function toggle(): void {
      if (WM.hasNativeOverview) { WM.toggleNativeOverview(); return }
      if (Theme.pillMode) AppState.toggleDashboard("overview", root.resolveMonitor())
      else root.togglePopup("overview")
    }
    function open(): void {
      if (WM.hasNativeOverview) { WM.openNativeOverview(); return }
      if (Theme.pillMode) AppState.openDashboard("overview", root.resolveMonitor())
      else root.openPopup("overview")
    }
    function close(): void {
      if (WM.hasNativeOverview) WM.closeNativeOverview()
      if (Theme.pillMode) { if (AppState.dashboardSection === "overview") AppState.closeDashboard() }
      else root.overviewOpen = false
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void {
      if (root.useRofiLauncher()) { root.openRofiLauncher(); return }
      root.launcherStartMode = "apps"
      root.togglePopup("launcher")
    }
    function open(mode: string): void {
      if (root.useRofiLauncher()) { root.openRofiLauncher(); return }
      const ok = ["apps", "windows", "run", "files", "commands", "tmux"]
      root.launcherStartMode = ok.indexOf(mode) >= 0 ? mode : "apps"
      root.openPopup("launcher")
    }
    function close(): void { root.launcherOpen = false }
  }

  IpcHandler {
    target: "nixsearch"
    function toggle(): void {
      root.nixStartQuery = ""
      root.nixStartInstalled = false
      root.togglePopup("nixsearch")
    }
    function open(query: string): void {
      root.nixStartQuery = query
      root.nixStartInstalled = false
      root.openPopup("nixsearch")
    }

    function installed(): void {
      root.nixStartQuery = ""
      root.nixStartInstalled = true
      root.openPopup("nixsearch")
    }
    function close(): void { root.nixSearchOpen = false }
  }

  IpcHandler {
    target: "screenshot"
    function areaCopy(): void { ScreenshotBackend.areaCopy() }
    function fullSave(): void { ScreenshotBackend.fullSave() }
    function areaSave(): void { ScreenshotBackend.areaSave() }
  }

  IpcHandler {
    target: "powermenu"
    function toggle(): void {
      if (Theme.pillMode) { AppState.toggleDashboard("power", root.focusedMonitor); return }
      if (root.useRofiPower()) { root.openRofiPower(); return }
      root.closeAllPopups()
      if (!root.powerOpen) root.focusedMonitor = root.resolveMonitor()
      root.powerOpen = !root.powerOpen
    }
    function open(): void {
      if (Theme.pillMode) { AppState.openDashboard("power", root.focusedMonitor); return }
      if (root.useRofiPower()) { root.openRofiPower(); return }
      root.closeAllPopups()
      root.focusedMonitor = root.resolveMonitor()
      root.powerOpen = true
    }
    function close(): void { root.powerOpen = false }
  }

  IpcHandler {
    target: "lock"
    function lock(): void {

      root.closeAllPopups()
      root.powerOpen = false
      root.wallsOpen = false
      lockScreen.lock()
    }
    function locked(): bool { return lockScreen.locked }
  }

  property bool wallsOpen:     false
  property bool mprisOpen:     false
  property bool keybindsOpen:  false
  property int  currentWallIndex: 0
  property bool monitorPickerOpen: false
  property bool monitorEditorOpen: false
  property bool langPickerOpen: false
  property bool appearancePickerOpen: false
  property bool barSettingsOpen: false
  property bool launcherSettingsOpen: false
  property bool terminalSettingsOpen: false
  property bool advancedSettingsOpen: false
  property bool menuOpen: false
  property string menuTab: "general"
  property bool notifyOpen: false
  property bool networkOpen: false
  property bool bluetoothOpen: false
  property bool audioOpen: false
  property bool overviewOpen: false

  property bool agendaOpen: false
  property bool launcherOpen: false
  property bool nixSearchOpen: false


  property string launcherStartMode: "apps"
  property string nixStartQuery: ""

  property bool nixStartInstalled: false


  property bool powerOpen: false

  // ─── Esquinas de pantalla ("marco") ─────────────────────────────


  property bool screenCorners: false


  onScreenCornersChanged: Theme.screenCorners = root.screenCorners
  property string cornersCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-corners"

  Process {
    id: loadCorners
    command: ["bash", "-c", "cat '" + root.cornersCacheFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadCorners.buffer += line }
    onRunningChanged: {
      if (!running) {
        const saved = loadCorners.buffer.trim()

        if (saved !== "") root.screenCorners = (saved === "1")
        loadCorners.buffer = ""
      }
    }
  }

  Process {
    id: saveCorners
    property string value: "1"
    command: ["bash", "-c", "echo -n '" + value + "' > '" + root.cornersCacheFile + "'"]
    running: false
  }

  function setScreenCorners(on) {
    root.screenCorners = on
    saveCorners.value = on ? "1" : "0"
    saveCorners.running = false
    saveCorners.running = true
  }


  // ─── Barra: posición y modo flotante ────────────────────────────


  // ─── Selector de monitor ────────────────────────────────────────


  property string targetMonitor: "DP-3"
  property string monitorCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-monitor"


  function resolveMonitor() {
    if (root.targetMonitor !== "auto") return root.targetMonitor
    const hm = WM.focusedMonitorName
    if (hm !== "") return hm

    return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : root.focusedMonitor
  }


  property string focusedMonitor: root.targetMonitor

  // ─── Perfiles visuales ──────────────────────────────────────────


  readonly property bool pillSurfaceActive: Theme.pillMode
  readonly property bool barSurfaceActive: !Theme.pillMode


  function isBarOnlyPopup(name) {
    return name === "overview" || name === "barsettings"
  }

  function popupAllowedInCurrentMode(name) {
    if (Theme.pillMode && root.isBarOnlyPopup(name)) return false
    return true
  }

  // ─── Popups de la barra ─────────────────────────────────────────


  function isPopupOpen(name) {
    return name === "menu" ? root.menuOpen
         : name === "notify" ? (Theme.pillMode ? root.notifyOpen : (root.menuOpen && root.menuTab === "notifs"))
         : name === "network" ? root.networkOpen
         : name === "bluetooth" ? root.bluetoothOpen
         : name === "audio" ? root.audioOpen
         : name === "appearance" ? root.appearancePickerOpen
         : name === "barsettings" ? root.barSettingsOpen
         : name === "launchersettings" ? root.launcherSettingsOpen
         : name === "terminalsettings" ? root.terminalSettingsOpen
         : name === "advancedsettings" ? root.advancedSettingsOpen
         : name === "monitor" ? root.monitorPickerOpen
         : name === "monitoreditor" ? root.monitorEditorOpen
         : name === "lang" ? root.langPickerOpen
         : name === "overview" ? root.overviewOpen
         : name === "agenda" ? root.agendaOpen
         : name === "keybinds" ? root.keybindsOpen
         : name === "launcher" ? root.launcherOpen
         : name === "nixsearch" ? root.nixSearchOpen
         : root.mprisOpen
  }

  function closeAllPopups() {
    root.closeAllPopupsExceptAdvanced()
    root.advancedSettingsOpen = false
  }


  function closeAllPopupsExceptAdvanced() {
    root.menuOpen = false
    root.menuTab = "general"
    root.notifyOpen = false
    root.networkOpen = false
    root.bluetoothOpen = false
    root.audioOpen = false
    root.mprisOpen = false
    root.appearancePickerOpen = false
    root.barSettingsOpen = false
    root.launcherSettingsOpen = false
    root.terminalSettingsOpen = false
    root.monitorPickerOpen = false
    root.monitorEditorOpen = false
    root.langPickerOpen = false
    root.overviewOpen = false
    root.agendaOpen = false
    root.keybindsOpen = false
    root.launcherOpen = false
    root.nixSearchOpen = false
    quickBar.close()
  }


  function openPopup(name, screen) {


    if (!root.popupAllowedInCurrentMode(name)) return


    if (name === "menu" && Theme.pillMode) {
      AppState.openDashboard("quickaccess", screen || root.resolveMonitor())
      return
    }

    if (name === "notify" && !Theme.pillMode) {
      root.closeAllPopupsExceptAdvanced()
      root.focusedMonitor = screen || root.resolveMonitor()
      root.menuTab = "notifs"
      root.menuOpen = true
      return
    }


    if (name === "advancedsettings") root.closeAllPopups()
    else root.closeAllPopupsExceptAdvanced()
    root.focusedMonitor = screen || root.resolveMonitor()


    if (Theme.pillMode && AppState.dashboardOpen) AppState.closeDashboard()
    if (name === "menu") root.menuOpen = true
    else if (name === "notify") root.notifyOpen = true
    else if (name === "network") root.networkOpen = true
    else if (name === "bluetooth") root.bluetoothOpen = true
    else if (name === "audio") root.audioOpen = true
    else if (name === "appearance") root.appearancePickerOpen = true
    else if (name === "barsettings") root.barSettingsOpen = true
    else if (name === "launchersettings") root.launcherSettingsOpen = true
    else if (name === "terminalsettings") root.terminalSettingsOpen = true
    else if (name === "advancedsettings") root.advancedSettingsOpen = true
    else if (name === "monitor") root.monitorPickerOpen = true
    else if (name === "monitoreditor") root.monitorEditorOpen = true
    else if (name === "lang") root.langPickerOpen = true
    else if (name === "overview") root.overviewOpen = true
    else if (name === "agenda") root.agendaOpen = true
    else if (name === "keybinds") root.keybindsOpen = true
    else if (name === "launcher") root.launcherOpen = true
    else if (name === "nixsearch") root.nixSearchOpen = true
    else root.mprisOpen = true
  }

  function togglePopup(name, screen) {

    if (name === "overview" && WM.hasNativeOverview) { root.closeAllPopups(); WM.toggleNativeOverview(); return }

    if (name === "menu" && Theme.pillMode) { AppState.toggleDashboard("quickaccess", screen || root.focusedMonitor); return }
    if (name === "notify" && !Theme.pillMode) {
      const showing = root.menuOpen && root.menuTab === "notifs"
      root.closeAllPopupsExceptAdvanced()
      if (!showing) {
        root.focusedMonitor = screen || root.resolveMonitor()
        root.menuTab = "notifs"
        root.menuOpen = true
      }
      return
    }
    if (!root.popupAllowedInCurrentMode(name)) return
    const wasOpen = root.isPopupOpen(name)
    if (name === "advancedsettings") root.closeAllPopups()
    else root.closeAllPopupsExceptAdvanced()
    if (!wasOpen) root.openPopup(name, screen)
  }


  property string pendingPopup: ""
  property string pendingScreen: ""
  function swapTo(name, screen) {
    if (!root.popupAllowedInCurrentMode(name)) return
    root.pendingPopup = name
    root.pendingScreen = screen || root.focusedMonitor


    popupSwapTimer.restart()
    root.closeAllPopups()
  }
  Timer {
    id: popupSwapTimer
    interval: 230
    repeat: false
    onTriggered: root.openPopup(root.pendingPopup, root.pendingScreen)
  }

  // ─── Volver al Dock ──────────────────────────────────────────────


  property string dashboardReturnScreen: ""
  property string pendingDashboardScreen: ""


  function openFromDashboard(name, screen) {
    const scr = screen ? screen.name : root.focusedMonitor
    root.dashboardReturnScreen = scr
    root.swapTo(name, scr)
  }


  function goBack(fallback) {
    if (root.dashboardReturnScreen === "") { root.swapTo(fallback); return }
    root.pendingDashboardScreen = root.dashboardReturnScreen
    root.dashboardReturnScreen = ""
    dashboardReturnTimer.restart()
    root.closeAllPopups()
  }
  Timer {
    id: dashboardReturnTimer
    interval: 230
    repeat: false
    onTriggered: AppState.openDashboard("quickaccess", root.pendingDashboardScreen)
  }


  onOtherBarPopupOpenChanged: {
    if (!root.otherBarPopupOpen && !popupSwapTimer.running && !dashboardReturnTimer.running)
      root.dashboardReturnScreen = ""
  }


  readonly property bool otherBarPopupOpen:
    root.menuOpen || root.networkOpen || root.bluetoothOpen
    || root.audioOpen || root.mprisOpen || root.overviewOpen || root.agendaOpen
    || root.appearancePickerOpen || root.monitorPickerOpen
    || root.monitorEditorOpen
    || root.barSettingsOpen || root.launcherSettingsOpen || root.terminalSettingsOpen || root.advancedSettingsOpen
    || root.langPickerOpen || root.keybindsOpen || root.powerOpen
    || root.launcherOpen || root.nixSearchOpen || quickBar.opened

  Binding {
    target: NotificationsBackend
    property: "otherPopupOpen"
    value: root.otherBarPopupOpen
  }


  Connections {
    target: Theme
    function onPillModeChanged() {


      root.closeAllPopupsExceptAdvanced()
      if (!Theme.pillMode) AppState.closeDashboard()
    }
    function onPerformanceToggled(on) {
      root.applyPerformanceProfile(on)


      toastOsd.show("󰓅", Translations.t("perfToastTitle"),
        Translations.t(on ? "perfToastOn" : "perfToastOff"), on)
    }
    function onIslandsModeChanged() {


      root.closeAllPopupsExceptAdvanced()
      if (Theme.islandsMode) AppState.closeDashboard()
    }
  }


  Process {
    id: waybarProc
    command: ["bash", Quickshell.env("HOME") + "/.config/waybar/waybar-launcher.sh"]
    running: Theme.usingWaybar
    stderr: SplitParser { onRead: line => console.log("[waybar]", line) }
  }
  Connections {
    target: WM
    function onWmChanged() {

      if (Theme.usingWaybar) { waybarProc.running = false; Qt.callLater(() => { waybarProc.running = Theme.usingWaybar }) }
    }
  }

  LazyLoader {


    active: ModeRuntime.barActive && !Theme.usingWaybar
    Bar {
        id: bar
        menuOpen: root.menuOpen
      notifyOpen: root.notifyOpen || (root.menuOpen && root.menuTab === "notifs")
      mprisOpen: root.mprisOpen
      audioOpen: root.audioOpen
      overviewOpen: root.overviewOpen
      agendaOpen: root.agendaOpen
      screenCorners: root.screenCorners
      popupOpen: root.menuOpen || root.notifyOpen || root.networkOpen
                 || root.bluetoothOpen
                 || root.audioOpen || root.mprisOpen || root.overviewOpen || root.agendaOpen
                 || root.appearancePickerOpen || root.monitorPickerOpen
                 || root.monitorEditorOpen
                 || root.barSettingsOpen || root.launcherSettingsOpen || root.terminalSettingsOpen || root.advancedSettingsOpen
                 || root.langPickerOpen || root.keybindsOpen || root.powerOpen
                 || root.launcherOpen || root.nixSearchOpen

      wallpaperChanging: walls.changing
      onTrayMenuOpened: root.closeAllPopups()
      onMenuButtonClicked: (screen) => { root.togglePopup("menu", screen.name) }
      onNotificationButtonClicked: (screen) => { root.togglePopup("notify", screen.name) }
      onOverviewButtonClicked: (screen) => { root.togglePopup("overview", screen.name) }
      onAgendaButtonClicked: (screen) => { root.togglePopup("agenda", screen.name) }
      onMprisButtonClicked: (screen) => { root.togglePopup("mpris", screen.name) }
      onAudioButtonClicked: (screen) => { root.togglePopup("audio", screen.name) }
          onPowerButtonClicked: (screen) => { root.focusedMonitor = screen.name; root.togglePowerMenu() }
      }
    }


  Binding {
    target: AppState
    property: "gapsOut"
    value: Number(root.appearance.gapsOut) || 0
  }

  // ─── Píldora (Theme.pillMode) ────────────────────────────────────


  Variants {
    model: Theme.pillMode ? Quickshell.screens : []
    delegate: Pill {
      required property var modelData
      targetScreen: modelData
      popupOpen: root.otherBarPopupOpen || root.notifyOpen


      notifyOpen: root.notifyOpen
      notifyScreen: root.focusedMonitor
      onRequestCloseNotify: root.notifyOpen = false
      onTrayMenuOpened: root.closeAllPopups()
      onNotificationButtonClicked: (screen) => { root.togglePopup("notify", screen.name) }


      onRequestNetwork: (screen) => { AppState.closeDashboard(); root.openFromDashboard("network", screen) }
      onRequestBluetooth: (screen) => { AppState.closeDashboard(); root.openFromDashboard("bluetooth", screen) }
      onRequestAppearance: (screen) => { AppState.closeDashboard(); root.openFromDashboard("appearance", screen) }
      onRequestWalls: (screen) => { AppState.closeDashboard(); root.wallsOpen = true }
      onRequestAdvancedSettings: (screen) => { AppState.closeDashboard(); root.openFromDashboard("advancedsettings", screen) }
    }
  }

  // ─── Dock ─────────────────────────────────────────────────────


  Dock {
    id: dock

    popupOpen: root.otherBarPopupOpen || root.notifyOpen
  }


  Process {
    id: loadMonitor
    command: ["bash", "-c", "cat '" + root.monitorCacheFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadMonitor.buffer += line }
    onRunningChanged: {
      if (!running) {
        const saved = loadMonitor.buffer.trim()
        if (saved !== "") root.targetMonitor = saved
        loadMonitor.buffer = ""
      }
    }
  }

  Process {
    id: saveMonitor
    property string value: ""
    command: ["bash", "-c", "echo -n " + "'" + value + "'" + " > '" + root.monitorCacheFile + "'"]
    running: false
  }

  function setMonitor(name) {
    root.targetMonitor = name
    root.focusedMonitor = root.resolveMonitor()
    saveMonitor.value = name
    saveMonitor.running = false
    saveMonitor.running = true
  }


  // ─── Selector de idioma ─────────────────────────────────────────


  property string currentLang: "en"
  property string langCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-lang"

  Process {
    id: loadLang
    command: ["bash", "-c", "cat '" + root.langCacheFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadLang.buffer += line }
    onRunningChanged: {
      if (!running) {
        const saved = loadLang.buffer.trim()
        if (saved !== "") root.currentLang = saved
        loadLang.buffer = ""
      }
    }
  }

  Process {
    id: saveLang
    property string value: ""
    command: ["bash", "-c", "echo -n " + "'" + value + "'" + " > '" + root.langCacheFile + "'"]
    running: false
  }

  function setLang(code) {
    root.currentLang = code
    saveLang.value = code
    saveLang.running = false
    saveLang.running = true
  }


  onCurrentLangChanged: Translations.current = root.currentLang


  LazyPopup {
    id: gateLang
    wanted: root.langPickerOpen
    LanguagePicker {
      id: languagePicker
      open: gateLang.open
      current: root.currentLang
      targetScreen: root.focusedMonitor
      onCloseRequested: root.langPickerOpen = false
      onBackRequested: root.swapTo("advancedsettings")
      onLanguageChosen: (code) => root.setLang(code)
    }
  }

  // ─── Ajustes (tamaño de la interfaz + foto de perfil + monitor/idioma) ─


  LazyPopup {
    id: gateAdvanced
    wanted: root.advancedSettingsOpen
    AdvancedSettings {
      id: advancedSettings
      open: gateAdvanced.open
      targetScreen: root.focusedMonitor
      appearanceValues: root.appearance
      animProfile: root.appearance.animProfile ?? "smooth"
      onAnimProfileChosen: (name) => root.setAnimProfile(name)
      onCloseRequested: root.advancedSettingsOpen = false
      onBackRequested: root.goBack("menu")
      onRequestMonitorEditor: root.swapTo("monitoreditor")


      targetMonitor: root.targetMonitor
      resolvedMonitor: root.resolveMonitor()
      onMonitorChosen: (name) => root.setMonitor(name)
      onLanguageChosen: (code) => root.setLang(code)
      onAppearancePreviewChanged: (key, value) => root.applyAppearanceLive(key, value)
      onAppearanceValueCommitted: (key, value) => root.setAppearanceValue(key, value)
      onAppearanceToggleChanged: (key, value) => root.setAppearanceValue(key, value)


      screenCorners: root.screenCorners
      onRequestCornersToggle: root.setScreenCorners(!root.screenCorners)
    }
  }


  LazyPopup {
    id: gateMonEditor
    wanted: root.monitorEditorOpen
    MonitorEditor {
      id: monitorEditor
      open: gateMonEditor.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.monitorEditorOpen = false
      onBackRequested: root.swapTo("advancedsettings")
    }
  }

  LazyLoader {


    active: ModeRuntime.barActive
    BarSettings {
      id: barSettings
      open: root.barSettingsOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.barSettingsOpen = false
      onBackRequested: root.swapTo("advancedsettings")
    }
  }

  LazyPopup {
    id: gateLauncherSet
    wanted: root.launcherSettingsOpen
    LauncherSettings {
      id: launcherSettings
      open: gateLauncherSet.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.launcherSettingsOpen = false
      onBackRequested: root.swapTo("advancedsettings")
    }
  }

  LazyPopup {
    id: gateTerminalSet
    wanted: root.terminalSettingsOpen
    TerminalSettings {
      id: terminalSettings
      open: gateTerminalSet.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.terminalSettingsOpen = false
      onBackRequested: root.swapTo("advancedsettings")
    }
  }

  // ─── Apariencia + Layouts ────────────────────────────────────────


  property var appearance: ({
    gapsIn: 3, gapsOut: 6, borderSize: 2,
    rounding: 10, roundingPower: 5,
    activeOpacity: 1.0, inactiveOpacity: 1.0,
    blurEnabled: true, blurSize: 3, blurPasses: 1,
    shadowEnabled: false, shadowRange: 3, shadowRenderPower: 1,
    animationsEnabled: true,
    animProfile: "smooth",
    layout: "dwindle"
  })
  property string appearanceCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-appearance.json"


  Process {
    id: loadAppearance
    command: ["bash", "-c", "cat '" + root.appearanceCacheFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadAppearance.buffer += line }
    onRunningChanged: {
      if (!running) {
        const saved = loadAppearance.buffer.trim()
        if (saved !== "") {
          try {
            root.appearance = Object.assign({}, root.appearance, JSON.parse(saved))
          } catch (e) {
            console.log("appearance cache parse error:", e)
          }
        }
        loadAppearance.buffer = ""


        const norm = WmAppearance.normalizeLayout(root.appearance.layout)
        if (norm !== root.appearance.layout) root.appearance = Object.assign({}, root.appearance, { layout: norm })
        WmAppearance.ensureAutogen(root.appearance)
      }
    }
  }


  function applyAppearanceLive(key, value) { WmAppearance.applyLive(key, value, root.appearance) }

  Process {
    id: saveAppearanceCache
    property string json: ""
    command: ["bash", "-c",
      "cat > '" + root.appearanceCacheFile + "' << 'OOZE_EOF'\n" + json + "\nOOZE_EOF\n"]
    running: false
  }

  function writeAppearanceCache() {
    saveAppearanceCache.json = JSON.stringify(root.appearance)
    saveAppearanceCache.running = false
    saveAppearanceCache.running = true
  }


  function writeThemeLua() { WmAppearance.writeTheme(root.appearance) }


  function writeLayoutsLua(layoutName) { WmAppearance.writeLayout(layoutName, false) }

  // ─── Estilo de animación → animprofile.lua ───────────────────────


  readonly property var animProfileNames: WmAppearance.animProfileNames


  function writeAnimProfileLua(reload) {
    WmAppearance.writeAnimProfile(root.appearance.animProfile, reload === true, root.appearance.animationsEnabled)
  }

  function setAnimProfile(name) {
    if (root.animProfileNames.indexOf(name) < 0) return
    const updated = Object.assign({}, root.appearance)
    updated.animProfile = name
    root.appearance = updated
    writeAppearanceCache()
    writeAnimProfileLua(true)
  }


  function setAppearanceValue(key, value) {
    const updated = Object.assign({}, root.appearance)
    updated[key] = value
    root.appearance = updated

    applyAppearanceLive(key, value)
    writeAppearanceCache()
    writeThemeLua()

    if (key === "animationsEnabled" && WM.wm === "niri") writeAnimProfileLua(false)
  }

  // ─── Modo PERFORMANCE ───────────────────────────────


  function applyPerformanceProfile(on) {
    const keys = ["blurEnabled", "shadowEnabled", "animationsEnabled"]
    const u = Object.assign({}, root.appearance)
    if (on) {
      if (!u.perfBackup) {
        const b = {}
        for (const k of keys) b[k] = u[k]
        u.perfBackup = b
      }
      u.blurEnabled = false; u.shadowEnabled = false; u.animationsEnabled = false
    } else {
      const b = u.perfBackup
      if (b) for (const k of keys) if (b[k] !== undefined) u[k] = b[k]
      delete u.perfBackup
    }
    root.appearance = u
    WmAppearance.applyPerformance(u)
    root.writeAppearanceCache()
    root.writeThemeLua()
    if (WM.wm === "niri") root.writeAnimProfileLua(false)
  }


  function setLayout(layoutName) {
    const name = WmAppearance.normalizeLayout(layoutName)
    const updated = Object.assign({}, root.appearance)
    updated.layout = name
    root.appearance = updated

    WmAppearance.applyLayoutLive(name)
    writeAppearanceCache()
    WmAppearance.writeLayout(name, true)


    NotificationsBackend.pushLocal("OozeShell", "Layout: " + name)
  }


  LazyPopup {
    id: gateAppearance
    wanted: root.appearancePickerOpen
    Appearance {
      id: appearancePanel
      open: gateAppearance.open
      values: root.appearance
      currentLayout: root.appearance.layout
      targetScreen: root.focusedMonitor
      onCloseRequested: root.appearancePickerOpen = false
      onBackRequested: root.goBack("menu")
      onPreviewChanged: (key, value) => root.applyAppearanceLive(key, value)
      onValueCommitted: (key, value) => root.setAppearanceValue(key, value)
      onToggleChanged: (key, value) => root.setAppearanceValue(key, value)
      onLayoutChosen: (name) => root.setLayout(name)
    }
  }


  Process {
    id: initColors
    command: ["bash", "-c",
      "F='" + Theme.colorsFile + "'; " +
      "[ -s \"$F\" ] && exit 0; " +
      "WP=$(cat ~/.cache/awww/last 2>/dev/null); " +
      "if [ -n \"$WP\" ] && [ -f \"$WP\" ]; then " +
      "  mkdir -p \"$(dirname \"$F\")\"; " +
      "  matugen image \"$WP\" --source-color-index 0 --json hex | sed -n '/^{/,/^}/p' > \"$F.tmp\"; " +
      "  if [ -s \"$F.tmp\" ]; then mv -f \"$F.tmp\" \"$F\"; else rm -f \"$F.tmp\"; fi; " +
      "fi"
    ]
    running: true
    onExited: Theme.reload()
  }


  // ─── Widgets de escritorio (capa bottom: sobre awww/mpvpaper, bajo ventanas) ───

  WidgetHost { id: widgetHost }

  Walls {
    id: walls
    onLiveSurfaceChanged: widgetHost.raise()
    open: root.wallsOpen
    currentIndex: root.currentWallIndex
    targetScreen: root.focusedMonitor
    onCurrentIndexChanged: root.currentWallIndex = walls.currentIndex
    onCloseRequested: root.wallsOpen = false


    onChangingChanged: Theme.wallpaperChanging = walls.changing
  }


  Notify {
    id: notify
    open: root.notifyOpen
    targetScreen: root.focusedMonitor
    onCloseRequested: root.notifyOpen = false
  }

  // ─── Calendario con ToDo ─────────────────────────────────────────


  LazyLoader {
    active: !Theme.pillMode
    AgendaPopup {
      id: agenda
      open: root.agendaOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.agendaOpen = false
    }
  }

  LazyPopup {
    id: gateMonSelect
    wanted: root.monitorPickerOpen
    MonitorSelect {
      id: monitorSelect
      open: gateMonSelect.open
      targetScreen: root.focusedMonitor
      current: root.targetMonitor
      resolvedCurrent: root.resolveMonitor()
      onCloseRequested: root.monitorPickerOpen = false
      onBackRequested: root.swapTo("advancedsettings")
      onMonitorChosen: (name) => root.setMonitor(name)
    }
  }


  // ─── Idioma de teclado ───────────────────────────────────────────


  LazyPopup {
    id: gateKeybinds
    wanted: root.keybindsOpen
    Keybinds {
      id: keybinds
      open: gateKeybinds.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.keybindsOpen = false
    }
  }

    IpcHandler {
    target: "mpris"
    function toggle() {
      if (Theme.pillMode) AppState.toggleDashboard("mpris", root.focusedMonitor)
      else root.togglePopup("mpris")
    }
  }

  LazyLoader {
    active: !Theme.pillMode
    Mpris {
      id: mpris
      open: root.mprisOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.mprisOpen = false
    }
  }


  LazyPopup {
    id: gateBluetooth
    wanted: root.bluetoothOpen
    BluetoothMenu {
      id: bluetoothMenu
      open: gateBluetooth.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.bluetoothOpen = false
      onBackRequested: root.goBack("menu")
    }
  }

  LazyPopup {
    id: gateNetwork
    wanted: root.networkOpen
    NetworkMenu {
      id: networkMenu
      open: gateNetwork.open
      targetScreen: root.focusedMonitor
      onCloseRequested: root.networkOpen = false
      onBackRequested: root.goBack("menu")
    }
  }

  // ─── Audio (salida/entrada + OSD, reemplaza swayosd) ────────────


  LazyLoader {
    active: !Theme.pillMode
    AudioMenu {
      id: audioMenu
      open: root.audioOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.audioOpen = false
    }
  }

  AudioOSD {
    id: audioOsd
    targetScreen: root.focusedMonitor
  }

  // ─── OSD de Caps Lock ───────────────────────────────────────────


  CapsOSD {
    id: capsOsd
    targetScreen: root.focusedMonitor
  }


  // ─── OSD de idioma del teclado (layout xkb) ─────────────────────


  LayoutOSD {
    id: layoutOsd
    targetScreen: root.focusedMonitor
  }


  // ─── OSD genérico (toast sin notificación) ──────────────────────


  ToastOSD {
    id: toastOsd
    targetScreen: root.focusedMonitor
  }


  // ─── Historial del portapapeles (cliphist + wl-clipboard) ───────


  ClipboardHistory {
    id: clipboardHistory
    targetScreen: root.focusedMonitor
  }


  // ─── Overview (vista general de los workspaces) ─────────────────


  LazyLoader {
    active: ModeRuntime.barActive
    Overview {
      id: overview
      open: root.overviewOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.overviewOpen = false
    }
  }

  // ─── Launcher (reemplaza el launcher de rofi) ───────────────────


  function rofiAvailable() { return WM.isInstalled("rofi") }
  function useRofiLauncher() { return Theme.launcherBackend === "rofi" && root.rofiAvailable() }
  function useRofiPower() { return Theme.powermenuBackend === "rofi" && root.rofiAvailable() }
  function openRofiLauncher() {
    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/rofi/Launcher/launcher.sh"])
  }
  function openRofiPower() {
    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/rofi/Powermenu/powermenu.sh"])
  }
  function togglePowerMenu() {
    if (root.useRofiPower()) { root.openRofiPower(); return }
    root.closeAllPopups()
    root.focusedMonitor = root.resolveMonitor()
    root.powerOpen = !root.powerOpen
  }


  Launcher {
    id: launcher
    open: root.launcherOpen
    startMode: root.launcherStartMode
    targetScreen: root.focusedMonitor
    onCloseRequested: root.launcherOpen = false
    onCommandRequested: (cmd, arg) => root.runLauncherCommand(cmd, arg)
  }

  // ─── Paleta de comandos del Launcher (`>`) ──────────────────────


  Timer {
    id: launcherCmdDelay
    property string cmd: ""
    interval: 350
    repeat: false
    onTriggered: {
      if (cmd === "shot-area-copy") ScreenshotBackend.areaCopy()
      else if (cmd === "shot-area-save") ScreenshotBackend.areaSave()
      else if (cmd === "shot-full-save") ScreenshotBackend.fullSave()
      cmd = ""
    }
  }

  function runLauncherCommand(cmd, arg) {
    root.launcherOpen = false
    switch (cmd) {
      case "settings":   root.openPopup("advancedsettings"); break
      case "appearance": root.openPopup("appearance"); break
      case "keybinds":   root.openPopup("keybinds"); break
      case "packages":
        root.nixStartQuery = ""
        root.nixStartInstalled = false
        root.openPopup("nixsearch")
        break
      case "monitor":    root.openPopup("monitor"); break
      case "lang":       root.openPopup("lang"); break
      case "network":    root.openPopup("network"); break
      case "bluetooth":  root.openPopup("bluetooth"); break
      case "notify":     root.openPopup("notify"); break
      case "audio":
        if (Theme.pillMode) AppState.openDashboard("audio", root.focusedMonitor)
        else root.openPopup("audio")
        break
      case "agenda":
        if (Theme.pillMode) AppState.openDashboard("calendar", root.focusedMonitor)
        else root.openPopup("agenda")
        break
      case "overview":
        if (WM.hasNativeOverview) WM.openNativeOverview()
        else if (Theme.pillMode) AppState.openDashboard("overview", root.resolveMonitor())
        else root.openPopup("overview")
        break
      case "walls":
        root.closeAllPopupsExceptAdvanced()
        root.focusedMonitor = root.resolveMonitor()
        root.wallsOpen = true
        break
      case "clipboard":  clipboardHistory.open(); break
      case "power":
        if (Theme.pillMode) { AppState.openDashboard("power", root.focusedMonitor); break }
        if (root.useRofiPower()) { root.openRofiPower(); break }
        root.closeAllPopups()
        root.focusedMonitor = root.resolveMonitor()
        root.powerOpen = true
        break
      case "lock":
        root.closeAllPopups()
        root.powerOpen = false
        root.wallsOpen = false
        lockScreen.lock()
        break
      case "theme":      Theme.setThemeMode(arg); break
      case "shot-area-copy":
      case "shot-area-save":
      case "shot-full-save":
        launcherCmdDelay.cmd = cmd
        launcherCmdDelay.restart()
        break
    }
  }

  // ─── Barra rápida ───────────────────────────────────────────────


  QuickBarHost {
    id: quickBar
    resolveScreen: () => root.resolveMonitor()

    onAboutToOpen: {
      root.closeAllPopups()
      root.focusedMonitor = root.resolveMonitor()
      if (Theme.pillMode && AppState.dashboardOpen) AppState.closeDashboard()
    }
  }

  // ─── Nix Search (reemplaza el script de rofi + nix-search) ──────


  LazyPopup {
    id: gateNix
    wanted: root.nixSearchOpen
    openDelay: 50
    PackageSearch {
      id: nixSearch
      open: gateNix.open
      startQuery: root.nixStartQuery
      startInstalled: root.nixStartInstalled
      targetScreen: root.focusedMonitor
      onCloseRequested: root.nixSearchOpen = false
    }
  }

  // ─── Capturas de pantalla (solo IPC, sin panel) ──────────────────


  ScreenshotFreeze {}

  // ─── Caffeine ───────────────────────────────────────────────────

  CaffeineInhibitor {}

  // ─── Menú de energía (reemplaza el powermenu.sh de rofi) ────────


  LazyLoader {
    active: ModeRuntime.barActive
    PowerMenu {
      id: powerMenu
      open: root.powerOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.powerOpen = false
    }
  }

  // ─── Pantalla de bloqueo (reemplaza a hyprlock) ─────────────────


  LockScreen {
    id: lockScreen
  }


  LazyLoader {
    active: ModeRuntime.barActive
    Menu {
      id: menu
      open: root.menuOpen
      startTab: root.menuTab
      onTabChanged: t => root.menuTab = t
      targetScreen: root.focusedMonitor
      onCloseRequested: root.menuOpen = false
      onRequestAppearance: root.swapTo("appearance")
      onRequestSettings: root.swapTo("advancedsettings")
      onRequestWalls: root.wallsOpen = true
      onRequestNetwork: root.swapTo("network")
      onRequestBluetooth: root.swapTo("bluetooth")
      screenCorners: root.screenCorners
      onRequestCornersToggle: root.setScreenCorners(!root.screenCorners)
    }
  }

}
