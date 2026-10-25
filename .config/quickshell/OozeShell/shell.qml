// shell.qml — SHELL

import Quickshell
import Quickshell.Io
import QtQuick
import "Services/Walls"
import "Services/Notify"
import "Services/Mpris"
import "Services/Monitor"
import "Modules/Keybinds"
import "Services/Launcher"
import "Modules/QuickBar"
import "Services/DefaultApps"
import "Services/PackageSearch"
import "Services/Screenshot"
import "Services/Lang"
import "Modules/Appearance"
import "Settings"
import "Modules/Bar"
import "Modules/Dock"
import "Modules/Dashboard"
import "Modules/SystemMonitor"
import "COMMON"
import "Services/Network"
import "Services/Bluetooth"
import "Services/Audio"
import "Services/Caps"
import "Modules/Overview"
import "Modules/Power"
import "Modules/Lock"
import "Modules/Pill"
import "Services/Agenda"
import "Services/Agents"
import "Services/Equalizer"
import "Services/Clipboard"
import "Services/Caffeine"
import "Modules/Widgets"
import "Core/Ipc"
import "Core"

ShellRoot {
  id: root

  // ─── IPC ───
  CornersIpc { shell: root }
  BarIpc { shell: root }
  CaffeineIpc { shell: root }
  MonitorIpc { shell: root }
  LangIpc { shell: root }
  SettingsIpc { shell: root }
  ThemeIpc { shell: root }
  AppearanceIpc { shell: root }
  ToggleWallsIpc { shell: root }
  NotifyIpc { shell: root }
  AgendaIpc { shell: root }
  PerformanceIpc { shell: root }
  KeybindsIpc { shell: root }
  KeyboardLayoutIpc { shell: root }
  MenuIpc { shell: root }
  NetworkIpc { shell: root }
  BluetoothIpc { shell: root }
  AudioIpc { shell: root }
  CapsIpc { shell: root; capsOsd: capsOsd }
  LayoutOsdIpc { shell: root; layoutOsd: layoutOsd }
  OsdIpc { shell: root; toastOsd: toastOsd }
  ClipboardIpc { shell: root; history: clipboardHistory }
  OverviewIpc { shell: root }
  LauncherIpc { shell: root }
  NixSearchIpc { shell: root }
  AgentIpc { shell: root }
  EqualizerIpc { shell: root }
  ScreenshotIpc { shell: root }
  RecordIpc { shell: root }
  PowerMenuIpc { shell: root }
  LockIpc { shell: root; lockScreen: lockScreen }
  MprisIpc { shell: root }
  SystemMonitorIpc { shell: root }
  WmIpc { shell: root }
  ConfigIpc { shell: root }
  StateIpc { shell: root }
  NativeIpc { shell: root }

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
  readonly property bool menuOpen: !Theme.pillMode && AppState.dashboardOpen
  readonly property bool dashboardNotifsOpen: AppState.dashboardOpen && AppState.dashboardSection === "notifs"
  readonly property bool dashboardAudioOpen: AppState.dashboardOpen && AppState.dashboardSection === "audio"
  readonly property bool dashboardCalendarOpen: AppState.dashboardOpen && AppState.dashboardSection === "calendar"
  property bool notifyOpen: false
  property bool networkOpen: false
  property bool bluetoothOpen: false
  property bool overviewOpen: false

  property bool launcherOpen: false
  property bool nixSearchOpen: false


  property string launcherStartMode: "apps"
  property string nixStartQuery: ""

  property bool nixStartInstalled: false


  property bool powerOpen: false

  // ─── Esquinas de pantalla ("marco") ─────────────────────────────


  property bool screenCorners: false


  onScreenCornersChanged: Theme.screenCorners = root.screenCorners

  Connections {
    target: StateStore
    function onLoaded() { root.applyStoredPrefs() }
  }
  function applyStoredPrefs() {
    const c = StateStore.get("corners")
    if (c === true || c === "1") root.screenCorners = WM.wm !== "mango"
    const m = StateStore.get("monitor")
    if (m !== undefined && m !== "") root.targetMonitor = m
    const l = StateStore.get("lang")
    if (l !== undefined && l !== "") {
      const known = Translations.availableLanguages.some(x => x.code === l)
      root.currentLang = known ? l : "en"
    }
    const a = StateStore.get("appearance")
    if (a !== undefined && typeof a === "object" && a !== null) {
      root.appearance = Object.assign({}, root.appearance, a)
      const norm = WmAppearance.normalizeLayout(root.appearance.layout)
      if (norm !== root.appearance.layout) root.appearance = Object.assign({}, root.appearance, { layout: norm })
      WmAppearance.ensureAutogen(root.appearance)
    }
  }

  function setScreenCorners(on) {
    const v = WM.wm === "mango" ? false : on
    root.screenCorners = v
    StateStore.set("corners", v)
  }


  // ─── Barra: posición y modo flotante ────────────────────────────


  // ─── Selector de monitor ────────────────────────────────────────


  property string targetMonitor: "DP-3"

  function setMonitor(name) {
    root.targetMonitor = name
    root.focusedMonitor = root.resolveMonitor()
    StateStore.set("monitor", name)
  }


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
    return name === "barsettings"
  }

  function popupAllowedInCurrentMode(name) {
    if (Theme.pillMode && root.isBarOnlyPopup(name)) return false
    return true
  }

  // ─── Popups de la barra ─────────────────────────────────────────


  function isPopupOpen(name) {
    return name === "menu" ? root.menuOpen
         : name === "notify" ? (Theme.pillMode ? root.notifyOpen : root.dashboardNotifsOpen)
         : name === "network" ? root.networkOpen
         : name === "bluetooth" ? root.bluetoothOpen
         : name === "audio" ? root.dashboardAudioOpen
         : name === "appearance" ? root.appearancePickerOpen
         : name === "barsettings" ? root.barSettingsOpen
         : name === "launchersettings" ? root.launcherSettingsOpen
         : name === "terminalsettings" ? root.terminalSettingsOpen
         : name === "advancedsettings" ? root.advancedSettingsOpen
         : name === "monitor" ? root.monitorPickerOpen
         : name === "monitoreditor" ? root.monitorEditorOpen
         : name === "lang" ? root.langPickerOpen
         : name === "overview" ? root.overviewOpen
         : name === "agenda" ? root.dashboardCalendarOpen
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
    if (!Theme.pillMode) AppState.closeDashboard()
    root.notifyOpen = false
    root.networkOpen = false
    root.bluetoothOpen = false
    root.mprisOpen = false
    root.appearancePickerOpen = false
    root.barSettingsOpen = false
    root.launcherSettingsOpen = false
    root.terminalSettingsOpen = false
    root.monitorPickerOpen = false
    root.monitorEditorOpen = false
    root.langPickerOpen = false
    root.overviewOpen = false
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
      AppState.openDashboard("notifs", root.focusedMonitor)
      return
    }

    if (name === "agenda" || name === "audio") {
      root.closeAllPopupsExceptAdvanced()
      root.focusedMonitor = screen || root.resolveMonitor()
      AppState.openDashboard(name === "agenda" ? "calendar" : "audio", root.focusedMonitor)
      return
    }


    if (name === "advancedsettings") root.closeAllPopups()
    else root.closeAllPopupsExceptAdvanced()
    root.focusedMonitor = screen || root.resolveMonitor()


    if (Theme.pillMode && AppState.pillLayerOpen) AppState.closeDashboard()
    if (name === "menu") AppState.openDashboard(null, root.focusedMonitor)
    else if (name === "notify") root.notifyOpen = true
    else if (name === "network") root.networkOpen = true
    else if (name === "bluetooth") root.bluetoothOpen = true
    else if (name === "appearance") root.appearancePickerOpen = true
    else if (name === "barsettings") root.barSettingsOpen = true
    else if (name === "launchersettings") root.launcherSettingsOpen = true
    else if (name === "terminalsettings") root.terminalSettingsOpen = true
    else if (name === "advancedsettings") root.advancedSettingsOpen = true
    else if (name === "monitor") root.monitorPickerOpen = true
    else if (name === "monitoreditor") root.monitorEditorOpen = true
    else if (name === "lang") root.langPickerOpen = true
    else if (name === "overview") root.overviewOpen = true
    else if (name === "keybinds") root.keybindsOpen = true
    else if (name === "launcher") root.launcherOpen = true
    else if (name === "nixsearch") root.nixSearchOpen = true
    else root.mprisOpen = true
  }

  function togglePopup(name, screen) {

    if (name === "overview" && WM.hasNativeOverview) { root.closeAllPopups(); WM.toggleNativeOverview(); return }

    if (name === "menu" && Theme.pillMode) { AppState.toggleDashboard("quickaccess", screen || root.focusedMonitor); return }
    if (name === "notify" && !Theme.pillMode) {
      const showing = AppState.dashboardOpen && AppState.dashboardSection === "notifs"
      root.closeAllPopupsExceptAdvanced()
      if (!showing) {
        root.focusedMonitor = screen || root.resolveMonitor()
        AppState.openDashboard("notifs", root.focusedMonitor)
      }
      return
    }
    if (name === "agenda" || name === "audio") {
      const sec = name === "agenda" ? "calendar" : "audio"
      const showing = AppState.dashboardOpen && AppState.dashboardSection === sec
      root.closeAllPopupsExceptAdvanced()
      if (!showing) {
        root.focusedMonitor = screen || root.resolveMonitor()
        AppState.openDashboard(sec, root.focusedMonitor)
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
    || root.mprisOpen || root.overviewOpen
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
      AppState.closeDashboard()
    }
    function onPerformanceToggled(on) {
      root.applyPerformanceProfile(Theme.compositorPerf)


      toastOsd.show("󰓅", Translations.t("perfToastTitle"),
        Translations.t(on ? "perfToastOn" : "perfToastOff"), on)
    }
    function onPerformanceScopeChanged() {
      root.applyPerformanceProfile(Theme.compositorPerf)
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
      StateStore.setWm(WM.wm)
      if (WM.wm === "mango" && root.screenCorners) root.setScreenCorners(false)
      if (Theme.usingWaybar) { waybarProc.running = false; Qt.callLater(() => { waybarProc.running = Theme.usingWaybar }) }
    }
  }
  Component.onCompleted: StateStore.setWm(WM.wm)

  LazyLoader {


    active: ModeRuntime.barActive && !Theme.usingWaybar
    Bar {
        id: bar
        menuOpen: root.menuOpen
      notifyOpen: root.notifyOpen || root.dashboardNotifsOpen
      mprisOpen: root.mprisOpen
      audioOpen: root.dashboardAudioOpen
      agendaOpen: root.dashboardCalendarOpen
      screenCorners: root.screenCorners
      popupOpen: root.menuOpen || root.notifyOpen || root.networkOpen
                 || root.bluetoothOpen
                 || root.mprisOpen || root.overviewOpen
                 || root.appearancePickerOpen || root.monitorPickerOpen
                 || root.monitorEditorOpen
                 || root.barSettingsOpen || root.launcherSettingsOpen || root.terminalSettingsOpen || root.advancedSettingsOpen
                 || root.langPickerOpen || root.keybindsOpen || root.powerOpen
                 || root.launcherOpen || root.nixSearchOpen

      wallpaperChanging: walls.changing
      onTrayMenuOpened: root.closeAllPopups()
      onMenuButtonClicked: (screen) => { root.togglePopup("menu", screen.name) }
      onNotificationButtonClicked: (screen) => { root.togglePopup("notify", screen.name) }
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


  // ─── Selector de idioma ─────────────────────────────────────────


  property string currentLang: "en"

  function setLang(code) {
    if (!Translations.availableLanguages.some(l => l.code === code)) return
    root.currentLang = code
    StateStore.set("lang", code)
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

  LazyPopup {
    id: gateBarSettings
    wanted: root.barSettingsOpen
    lazy: Theme.lazyPanels
    available: ModeRuntime.barActive
    BarSettings {
      id: barSettings
      open: gateBarSettings.open
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
  function applyAppearanceLive(key, value) { WmAppearance.applyLive(key, value, root.appearance) }

  function writeAppearanceCache() {
    StateStore.setCommon("appearance", root.appearance)
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
    if (!on && !u.perfBackup) return
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


  readonly property string daemonPath:
    decodeURIComponent(Qt.resolvedUrl("Backends/python/ooze-daemon.py").toString().replace("file://", ""))

  Process {
    id: initColors
    command: ["python3", root.daemonPath, "palette-file",
      "--out", Theme.colorsFile, "--index", "0",
      "--last", Quickshell.env("HOME") + "/.cache/awww/last"]
    running: true
    onExited: Theme.reload()
  }


  // ─── Widgets de escritorio (capa bottom: sobre awww/mpvpaper, bajo ventanas) ───

  WidgetHost { id: widgetHost }

  LazyPopup {
    id: gateWidgetQuick
    wanted: WidgetConfig.quickOpen
    WidgetQuickSettings { open: gateWidgetQuick.open }
  }

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

  // ─── Selector de monitor ─────────────────────────────────────────


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

  LazyPopup {
    id: gateMpris
    wanted: root.mprisOpen
    lazy: Theme.lazyPanels
    available: !Theme.pillMode
    Mpris {
      id: mpris
      open: gateMpris.open
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

  // ─── Audio OSD (reemplaza swayosd) ──────────────────────────────


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


  // ─── Toast de alarmas (Agenda / Pomodoro, ignora No Molestar) ───


  AlarmToast {
    id: alarmToast
    targetScreen: root.focusedMonitor
  }


  // ─── Historial del portapapeles (cliphist + wl-clipboard) ───────


  ClipboardHistory {
    id: clipboardHistory
    targetScreen: root.focusedMonitor
  }


  // ─── Overview (cuadrícula de todas las ventanas) ───────────────


  LazyPopup {
    id: gateOverview
    wanted: root.overviewOpen
    Overview {
      id: overview
      open: gateOverview.open
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
      else if (cmd === "rec-area") RecorderBackend.startArea()
      else if (cmd === "rec-screen") RecorderBackend.startScreen()
      else if (cmd === "rec-stop") RecorderBackend.stop()
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
        root.openPopup("audio")
        break
      case "agenda":
        root.openPopup("agenda")
        break
      case "overview":
        if (WM.hasNativeOverview) WM.openNativeOverview()
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
      case "rec-area":
      case "rec-screen":
      case "rec-stop":
        launcherCmdDelay.cmd = cmd
        launcherCmdDelay.restart()
        break
    }
  }

  // ─── QuickSearch ───────────────────────────────────────────────


  QuickBarHost {
    id: quickBar
    resolveScreen: () => root.resolveMonitor()

    onAboutToOpen: {
      root.closeAllPopups()
      root.focusedMonitor = root.resolveMonitor()
      if (Theme.pillMode && AppState.pillLayerOpen) AppState.closeDashboard()
    }
  }

  // ─── Apps predeterminadas ───────────────────────────────────────

  DefaultAppsHost {}

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

  LazyPopup {
    id: gateAgent
    wanted: AgentsService.open
    openDelay: 30
    AgentBubble {
      open: gateAgent.open
      onCloseRequested: AgentsService.closeBubble()
    }
  }

  LazyPopup {
    id: gateEqualizer
    wanted: EqualizerService.open
    openDelay: 30
    EqualizerWindow {
      open: gateEqualizer.open
      onCloseRequested: EqualizerService.closeWindow()
    }
  }

  // ─── Capturas de pantalla (solo IPC, sin panel) ──────────────────


  ScreenshotFreeze {}

  // ─── Caffeine ───────────────────────────────────────────────────

  function caffeineToast() {
    const on = CaffeineBackend.active
    toastOsd.show(on ? OozeIcons.caffeine : OozeIcons.caffeineOff, Translations.t("caffeineTitle"),
      Translations.t(on ? "caffeineToastOn" : "caffeineToastOff"), on)
  }

  CaffeineInhibitor {}

  // ─── Menú de energía (reemplaza el powermenu.sh de rofi) ────────


  LazyPopup {
    id: gatePower
    wanted: root.powerOpen
    lazy: Theme.lazyPanels
    available: ModeRuntime.barActive
    PowerMenu {
      id: powerMenu
      open: gatePower.open
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
    DashboardPanel {
      id: dashboardPanel
      open: root.menuOpen
      targetScreen: root.focusedMonitor
      onRequestAppearance: root.swapTo("appearance")
      onRequestAdvancedSettings: root.swapTo("advancedsettings")
      onRequestWalls: { AppState.closeDashboard(); root.wallsOpen = true }
      onRequestNetwork: root.swapTo("network")
      onRequestBluetooth: root.swapTo("bluetooth")
    }
  }

  // ─── System Monitor (ventana de aplicación, solo bind/IPC) ──────


  Item {
    SystemMonitorWindow {
      id: systemMonitor
    }
  }

}
