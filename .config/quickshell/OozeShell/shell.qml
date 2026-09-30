// OozeShell Wallpapers and More

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "./WALLS"
import "./NOTIFY"
import "./MPRIS"
import "./MONITOR"
import "./Keybinds"
import "./Launcher"
import "./NixSearch"
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


ShellRoot {
  id: root

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
  property bool notifyOpen: false
  property bool networkOpen: false
  property bool bluetoothOpen: false
  property bool audioOpen: false
  property bool overviewOpen: false
  // Calendario con ToDo (clic derecho en el reloj; AGENDA/AgendaPopup.qml)
  property bool agendaOpen: false
  property bool launcherOpen: false
  property bool nixSearchOpen: false
  // Argumentos de apertura de Launcher / NixSearch. Viven acá (y no en el popup)
  // porque el popup solo existe mientras está abierto (LazyPopup): los IPC los
  // escriben ANTES de abrir, y el popup los lee al crearse.
  property string launcherStartMode: "apps"
  property string nixStartQuery: ""
  // Menú de energía (pantalla completa, modal): NO es un popup de la barra,
  // por eso no entra en isPopupOpen/closeAllPopups. Ver POWER/PowerMenu.qml.
  property bool powerOpen: false

  // ─── Esquinas de pantalla ("marco") ─────────────────────────────
  // Las 4 piecitas curvas de Bar.qml. Mismo patrón que monitor/lang:
  // persistido en disco y cambiable en caliente por IPC, además del botón
  // del Menú (junto al usuario).
  //   quickshell ipc -p .../shell.qml call -- corners toggle
  //   quickshell ipc -p .../shell.qml call -- corners set true
  //   quickshell ipc -p .../shell.qml call -- corners get
  property bool screenCorners: true
  // Espejo en Theme: así cualquier popup (Menu, AudioMenu, NetworkMenu...)
  // puede leer "¿el marco está prendido?" sin que shell.qml tenga que
  // pasárselo como prop uno por uno (son ~15 archivos). Theme.frameSideArm
  // (COMMON/Theme.qml) es lo que en realidad usan para su alignMargin.
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
        // Sin archivo todavía = queda el valor por defecto (activadas)
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

  IpcHandler {
    target: "corners"
    function toggle(): void { root.setScreenCorners(!root.screenCorners) }
    function set(on: bool): void { root.setScreenCorners(on) }
    function get(): bool { return root.screenCorners }
  }

  // ─── Barra: posición y modo flotante ────────────────────────────
  // También desde Ajustes → Interfaz. Se persiste en ui.json (Theme).
  //   quickshell ipc -p .../shell.qml call -- bar position top|bottom|left|right
  //   quickshell ipc -p .../shell.qml call -- bar togglePosition
  //   quickshell ipc -p .../shell.qml call -- bar floating true|false
  //   quickshell ipc -p .../shell.qml call -- bar toggleFloating
  //   quickshell ipc -p .../shell.qml call -- bar islands true|false
  //   quickshell ipc -p .../shell.qml call -- bar toggleIslands
  //   quickshell ipc -p .../shell.qml call -- bar get
  // togglePosition da la vuelta al lado opuesto sobre el mismo eje
  // (top↔bottom, left↔right). Flotante solo tiene efecto con la barra
  // arriba o abajo; la preferencia se guarda igual.
  IpcHandler {
    target: "bar"
    function position(p: string): void { Theme.setBarPosition(p) }
    function togglePosition(): void {
      const flip = { top: "bottom", bottom: "top", left: "right", right: "left" }
      Theme.setBarPosition(flip[Theme.barPosition] ?? "top")
    }
    function floating(on: bool): void { Theme.setBarFloating(on) }
    function toggleFloating(): void { Theme.setBarFloating(!Theme.barFloatingPref) }
    // Modo Islas: sin fondo de barra, cada popup nace de su isla
    function islands(on: bool): void { Theme.setIslandsEnabled(on) }
    function toggleIslands(): void { Theme.setIslandsEnabled(!Theme.islandsPref) }
    function pill(on: bool): void { Theme.setPillModeEnabled(on) }
    function togglePill(): void { Theme.setPillModeEnabled(!Theme.pillModePref) }
    function get(): string {
      return JSON.stringify({ position: Theme.barPosition, floating: Theme.barFloatingPref,
                              islands: Theme.islandsPref, pill: Theme.pillModePref })
    }
  }

  // ─── Selector de monitor ────────────────────────────────────────
  // Un solo lugar para decidir en qué pantalla vive el shell.
  // Walls/Notify/Mpris leen esta property en vez de tener el nombre
  // de la pantalla hardcodeado cada uno. Se persiste en disco para
  // que sobreviva a un reinicio de Quickshell, y se puede cambiar
  // en caliente por IPC sin editar QML ni reiniciar nada:
  //   quickshell ipc -p .../shell.qml call -- monitor set DP-3
  //   quickshell ipc -p .../shell.qml call -- monitor set auto
  //   quickshell ipc -p .../shell.qml call -- monitor list
  //   quickshell ipc -p .../shell.qml call -- monitor get
  //   quickshell ipc -p .../shell.qml call -- monitor current
  //
  // targetMonitor puede ser el nombre de una pantalla fija (DP-3, HDMI-A-1,
  // etc.) o el valor especial "auto": en ese modo no hay pantalla fija,
  // sino que cada cosa que se abre sin saber "desde dónde" la llamaron
  // (IPC, atajo de teclado) usa resolveMonitor() de abajo, que pregunta a
  // Hyprland cuál es la pantalla bajo el mouse en ESE momento.
  property string targetMonitor: "DP-3"
  property string monitorCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-monitor"

  // Pantalla que usa Hyprland "ahora": Hyprland actualiza esto solo, sin
  // necesidad de click, apenas el mouse cruza a otro monitor. Es la base
  // del modo "auto".
  function resolveMonitor() {
    if (root.targetMonitor !== "auto") return root.targetMonitor
    const hm = Hyprland.focusedMonitor
    if (hm && hm.name) return hm.name
    // Sin info de Hyprland todavía (arranque): primera pantalla conocida.
    return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : root.focusedMonitor
  }

  // focusedMonitor: pantalla donde se abre el PRÓXIMO popup/menú/toggle.
  // Es lo que usan todos los `targetScreen:` de acá abajo — targetMonitor
  // sigue siendo el "monitor por defecto" que se elige a mano en Ajustes
  // (y el que se persiste en disco); focusedMonitor arranca igual a ese
  // valor pero cada botón de la barra lo actualiza a SU propia pantalla
  // al tocarlo (ver Bar{} más abajo), así el panel aparece donde uno está
  // parado en vez de saltar siempre a la pantalla "por defecto".
  // Los toggles disparados por IPC/atajo de teclado (sin click en la
  // barra) no tienen forma de saber dónde estás, así que usan el último
  // focusedMonitor conocido (o targetMonitor si todavía no tocaste nada).
  property string focusedMonitor: root.targetMonitor

  // ─── Perfiles visuales ──────────────────────────────────────────
  // Hay dos superficies de la shell, mutuamente excluyentes:
  //   • Barra / Islas: usa los módulos BAR y sus popups propios.
  //   • Píldora: usa PILL + Dashboard; no monta los popups que solo
  //     duplican funciones ya presentes en el Dashboard.
  // Todo lo demás (notificaciones, launcher, ajustes, red, Bluetooth,
  // wallpaper, energía, etc.) sigue siendo compartido.
  readonly property bool pillSurfaceActive: Theme.pillMode
  readonly property bool barSurfaceActive: !Theme.pillMode

  // Popups que tienen sustituto directo dentro de PILL/Dashboard.
  // Sus IPC se redirigen más abajo, así que nunca necesitamos tener dos
  // superficies equivalentes abiertas al mismo tiempo.
  function isBarOnlyPopup(name) {
    return name === "overview" || name === "barsettings"
  }

  function popupAllowedInCurrentMode(name) {
    if (Theme.pillMode && root.isBarOnlyPopup(name)) return false
    return true
  }

  // ─── Popups de la barra ─────────────────────────────────────────
  // menu / notify / network / bluetooth / audio / mpris / appearance / settings / barsettings / launchersettings / terminalsettings / monitor / lang / overview / keybinds / launcher / nixsearch.
  // Todos cuelgan de la barra y comparten zona, así que son
  // excluyentes: abrir uno cierra los otros (antes se apilaban).
  function isPopupOpen(name) {
    return name === "menu" ? root.menuOpen
         : name === "notify" ? root.notifyOpen
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

  // Igual que closeAllPopups() pero deja Ajustes avanzados como está.
  // Así, abrir cualquier otro popup de la barra (ej. el Launcher) NO
  // tapa/cierra Ajustes avanzados: quedan los dos abiertos a la vez.
  // Ajustes avanzados solo se cierra cuando se lo pide explícitamente
  // (su propia X/Esc, el IPC `settings close`, o al togglearlo/abrirlo
  // a él mismo — ver openPopup()/togglePopup() más abajo).
  function closeAllPopupsExceptAdvanced() {
    root.menuOpen = false
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
  }

  // screen es opcional: lo pasan los botones de la barra, que SÍ saben en
  // qué pantalla física los tocaste. Si no viene (IPC, atajo de teclado,
  // navegación interna entre popups), se resuelve solo con
  // resolveMonitor() — fijo o "auto" según targetMonitor.
  function openPopup(name, screen) {
    // En Píldora no existen superficies equivalentes para estos popups:
    // el Overview y los ajustes específicos de la barra no deben aparecer
    // como tarjetas flotantes fuera de contexto.
    if (!root.popupAllowedInCurrentMode(name)) return

    // Ajustes avanzados es la única excepción a "abrir uno cierra los
    // demás": si lo que se abre ES Ajustes avanzados, sí se cierra todo
    // (incluido él mismo, por las dudas) antes de mostrarlo; si se abre
    // CUALQUIER OTRO popup, Ajustes avanzados se deja como está.
    if (name === "advancedsettings") root.closeAllPopups()
    else root.closeAllPopupsExceptAdvanced()
    root.focusedMonitor = screen || root.resolveMonitor()
    // Modo Píldora: si el Dashboard (dock expandido) estaba abierto, se cierra.
    // Abrir un popup por IPC / atajo (ej. `monitor togglePicker`) no pasaba por
    // los botones del dock que ya lo cerraban, así que el dock seguía
    // expandido ENCIMA de la tarjeta que nace de la píldora: las dos
    // superficies se pisaban (el "se buguea" y el lag al abrir).
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
    if (!root.popupAllowedInCurrentMode(name)) return
    const wasOpen = root.isPopupOpen(name)
    if (name === "advancedsettings") root.closeAllPopups()
    else root.closeAllPopupsExceptAdvanced()
    if (!wasOpen) root.openPopup(name, screen)
  }

  // Pasar de un popup a otro (ej. Menu → Network): primero se cierra el
  // actual y, cuando termina su animación, se abre el siguiente en el
  // mismo sitio. Así no se pisan dos paneles a la vez. Se queda en la
  // misma pantalla donde ya estaba (no vuelve a resolver "auto": si abrí
  // Ajustes en la pantalla 2, Ajustes→Monitor también aparece ahí).
  property string pendingPopup: ""
  property string pendingScreen: ""
  function swapTo(name, screen) {
    if (!root.popupAllowedInCurrentMode(name)) return
    root.pendingPopup = name
    root.pendingScreen = screen || root.focusedMonitor
    // El timer arranca ANTES de cerrar: así onOtherBarPopupOpenChanged sabe
    // que es una navegación entre popups y no un cierre definitivo.
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
  // Los accesos de Dashboard → Ajustes (Red, Bluetooth, Apariencia,
  // Ajustes avanzados) abren su popup de siempre, pero su flecha "atrás"
  // llevaba al Menu clásico. Si el popup se abrió DESDE el dock, atrás
  // vuelve al dock (sección Ajustes) en la misma pantalla. Vale también
  // para las subpáginas (Avanzados → Monitores → atrás → atrás).
  property string dashboardReturnScreen: ""
  property string pendingDashboardScreen: ""

  // Abre `name` desde el dock recordando a qué pantalla volver.
  function openFromDashboard(name, screen) {
    const scr = screen ? screen.name : root.focusedMonitor
    root.dashboardReturnScreen = scr
    root.swapTo(name, scr)
  }

  // Flecha atrás de un popup: al dock si venía de ahí; si no, al `fallback`.
  function goBack(fallback) {
    if (root.dashboardReturnScreen === "") { root.swapTo(fallback); return }
    root.pendingDashboardScreen = root.dashboardReturnScreen
    root.dashboardReturnScreen = ""
    dashboardReturnTimer.restart()   // antes de cerrar, mismo motivo que swapTo
    root.closeAllPopups()
  }
  Timer {
    id: dashboardReturnTimer
    interval: 230   // deja terminar la animación de cierre del popup
    repeat: false
    onTriggered: AppState.openDashboard("quickaccess", root.pendingDashboardScreen)
  }

  // Cerrar el popup por cualquier otra vía (X, Esc, clic afuera, atajo)
  // cancela el "volver al dock": una apertura posterior desde el Menu
  // clásico no debe terminar abriendo el dock.
  onOtherBarPopupOpenChanged: {
    if (!root.otherBarPopupOpen && !popupSwapTimer.running && !dashboardReturnTimer.running)
      root.dashboardReturnScreen = ""
  }

  // Mismo agregado que arma `popupOpen` para la barra (ver más abajo), sin
  // "notify": ese caso ya lo cubre NotificationsBackend.centerOpen. Un
  // Binding en vez de tocar Notify.qml/Bar.qml: NotificationsBackend es un
  // singleton, así que se le puede asignar la propiedad desde cualquier
  // lado sin que ese componente necesite saber nada de este flag.
  readonly property bool otherBarPopupOpen:
    root.menuOpen || root.networkOpen || root.bluetoothOpen
    || root.audioOpen || root.mprisOpen || root.overviewOpen || root.agendaOpen
    || root.appearancePickerOpen || root.monitorPickerOpen
    || root.monitorEditorOpen
    || root.barSettingsOpen || root.launcherSettingsOpen || root.terminalSettingsOpen || root.advancedSettingsOpen
    || root.langPickerOpen || root.keybindsOpen || root.powerOpen
    || root.launcherOpen || root.nixSearchOpen

  Binding {
    target: NotificationsBackend
    property: "otherPopupOpen"
    value: root.otherBarPopupOpen
  }

  // Al cambiar de modo se cierra lo que estuviera abierto (los popups de barra
  // se desmontan en modo Píldora y el Dashboard solo existe en ese modo).
  Connections {
    target: Theme
    function onPillModeChanged() {
      // Cambiar de superficie nunca deja una tarjeta de la superficie
      // anterior flotando. El Dashboard solo existe en Píldora.
      root.closeAllPopups()
      if (!Theme.pillMode) AppState.closeDashboard()
    }
    function onIslandsModeChanged() {
      // Islas sigue siendo la variante de BAR, pero el cambio de perfil
      // debe empezar limpio igual que Píldora.
      root.closeAllPopups()
      if (Theme.islandsMode) AppState.closeDashboard()
    }
  }

  LazyLoader {
    // La superficie clásica no existe en Píldora: no basta con ocultarla,
    // porque sus Variants/PanelWindow por pantalla siguen siendo objetos QML.
    active: !Theme.pillMode
    Bar {
        id: bar
        menuOpen: root.menuOpen
      notifyOpen: root.notifyOpen
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
      // Solo mientras se recargan los colores (no por abrir el selector)
      wallpaperChanging: walls.changing
      onTrayMenuOpened: root.closeAllPopups()
      onMenuButtonClicked: (screen) => { root.togglePopup("menu", screen.name) }
      onNotificationButtonClicked: (screen) => { root.togglePopup("notify", screen.name) }
      onOverviewButtonClicked: (screen) => { root.togglePopup("overview", screen.name) }
      onAgendaButtonClicked: (screen) => { root.togglePopup("agenda", screen.name) }
      onMprisButtonClicked: (screen) => { root.togglePopup("mpris", screen.name) }
      onAudioButtonClicked: (screen) => { root.togglePopup("audio", screen.name) }
          onPowerButtonClicked: (screen) => { root.focusedMonitor = screen.name; root.closeAllPopups(); root.powerOpen = !root.powerOpen }
      }
    }

  // Gaps out de Hyprland → AppState (Pill.qml calcula su zona reservada con él)
  Binding {
    target: AppState
    property: "gapsOut"
    value: Number(root.appearance.gapsOut) || 0
  }

  // ─── Píldora (Theme.pillMode) ────────────────────────────────────
  // Superficie totalmente aparte de Bar (ver PILL/Pill.qml + especificación
  // "Pill + Dashboard + Tray"): Bar{} de arriba ya se desmonta sola en este
  // modo (Bar.qml → model: Theme.pillMode ? [] : Quickshell.screens), así
  // que acá solo hace falta prender esto. Una instancia por pantalla, igual
  // que Bar.
  Variants {
    model: Theme.pillMode ? Quickshell.screens : []
    delegate: Pill {
      required property var modelData
      targetScreen: modelData
      popupOpen: root.otherBarPopupOpen || root.notifyOpen
      onTrayMenuOpened: root.closeAllPopups()
      onNotificationButtonClicked: (screen) => { root.togglePopup("notify", screen.name) }
      // Dock (estado expandido de la Pastilla): cada acción cierra el
      // Dashboard y abre el popup de siempre, igual que hacía Menu.qml.
      onRequestNetwork: (screen) => { AppState.closeDashboard(); root.openFromDashboard("network", screen) }
      onRequestBluetooth: (screen) => { AppState.closeDashboard(); root.openFromDashboard("bluetooth", screen) }
      onRequestAppearance: (screen) => { AppState.closeDashboard(); root.openFromDashboard("appearance", screen) }
      onRequestWalls: (screen) => { AppState.closeDashboard(); root.wallsOpen = true }
      onRequestAdvancedSettings: (screen) => { AppState.closeDashboard(); root.openFromDashboard("advancedsettings", screen) }
    }
  }

  // ─── Dock ─────────────────────────────────────────────────────
  // Encendido/apagado en Ajustes → Interfaz → Dock (Theme.dockEnabled).
  // Igual que Bar, Dock.qml ya trae adentro su propio Variants por pantalla.
  Dock {
    id: dock
    // Mismo criterio que la barra: con un popup abierto no hay tooltips
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

  IpcHandler {
    target: "monitor"
    // name también acepta "auto"
    function set(name: string): void { root.setMonitor(name) }
    // Valor crudo de la preferencia ("DP-3" o "auto")
    function get(): string { return root.targetMonitor }
    function togglePicker(): void { root.togglePopup("monitor") }
    // Lista las pantallas conectadas ahora mismo, así no hay que
    // adivinar el nombre exacto (DP-3, HDMI-A-1, etc).
    function list(): string {
      return Quickshell.screens.map(s => s.name).join(", ")
    }
    // Pantalla que se usaría AHORA MISMO si algo se abriera ya: igual a
    // get() salvo en modo "auto", donde muestra la detectada por el mouse.
    function current(): string { return root.resolveMonitor() }
  }

  // ─── Selector de idioma ─────────────────────────────────────────
  // Mismo patrón que targetMonitor: una property global, persistida
  // en disco, cambiable en caliente por IPC. Cualquier componente
  // que quiera texto traducido importa "./LANG" y lee
  // Translations.t("clave") o Translations.sections() — no hace
  // falta pasarle el idioma a mano a cada uno, porque Translations
  // es un singleton compartido por todo el shell.
  //   quickshell ipc -p .../shell.qml call -- lang set es
  //   quickshell ipc -p .../shell.qml call -- lang togglePicker
  //   quickshell ipc -p .../shell.qml call -- lang get
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

  // Mantiene el singleton Translations sincronizado con la
  // property persistida (incluida la carga inicial desde disco).
  onCurrentLangChanged: Translations.current = root.currentLang

  IpcHandler {
    target: "lang"
    function set(code: string): void { root.setLang(code) }
    function get(): string { return root.currentLang }
    function togglePicker(): void { root.togglePopup("lang") }
    function list(): string {
      return Translations.availableLanguages.map(l => l.code + " (" + l.name + ")").join(", ")
    }
  }

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
  // El estado vive en singletons de COMMON/ (se persiste en
  // ~/.config/oozeshell/): Theme guarda los 3 niveles de tamaño
  // (Theme.fontLevel / barLevel / windowLevel, de 0 = Pequeño a
  // 4 = Exorbitante) y UserProfile la foto.
  //
  // El panel chico "Ajustes" (con pestañas y animaciones) se eliminó: todas
  // sus opciones viven ahora directo en Ajustes avanzados (categorías
  // Perfil / General), sin ventana intermedia — así cambiar un ajuste no
  // cierra nada. El IPC se mantiene igual (mismo target/función/nombre),
  // solo que ahora abre directo Ajustes avanzados.
  //   quickshell ipc -p .../shell.qml call -- settings toggle
  //   quickshell ipc -p .../shell.qml call -- settings open
  //   quickshell ipc -p .../shell.qml call -- settings close
  //   quickshell ipc -p .../shell.qml call -- settings get
  //   quickshell ipc -p .../shell.qml call -- settings setUi 3        (barra + ventanas)
  //   quickshell ipc -p .../shell.qml call -- settings setLevel font 4   (font | bar | window)
  //   quickshell ipc -p .../shell.qml call -- settings reset
  // `open`/`close`/`toggle` son las 3 formas de llamar a Ajustes avanzados
  // desde un bind de Hyprland (igual que launcher/overview/powermenu).
  // Ajustes avanzados es además el único popup que NO se cierra solo
  // porque se abra otro (ej. el Launcher encima): ver
  // closeAllPopupsExceptAdvanced() más arriba.
  IpcHandler {
    target: "settings"
    function toggle(): void { root.togglePopup("advancedsettings") }
    function open(): void { root.openPopup("advancedsettings") }
    function close(): void { root.advancedSettingsOpen = false }
    function get(): string {
      return JSON.stringify({ font: Theme.fontLevel, bar: Theme.barLevel, window: Theme.windowLevel })
    }
    function setUi(level: int): void { Theme.setInterfaceLevel(level) }
    function setLevel(kind: string, level: int): void { Theme.setLevel(kind, level) }
    function reset(): void { Theme.resetLevels() }
  }

  // Modo claro / oscuro (también está en Ajustes → Interfaz → Tema)
  //   quickshell ipc -p .../shell.qml call -- theme mode light|dark
  //   quickshell ipc -p .../shell.qml call -- theme toggle
  //   quickshell ipc -p .../shell.qml call -- theme get
  IpcHandler {
    target: "theme"
    function mode(m: string): void { Theme.setLightMode(m === "light") }
    function toggle(): void { Theme.setLightMode(!Theme.lightMode) }
    function get(): string { return Theme.schemeMode }
    // Estilo visual: `theme style cozy` (CoOzey) | `theme style soft` (OozeSoft)
    function style(s: string): void { Theme.setUiStyle(s) }
    function styleGet(): string { return Theme.uiStyle }
  }

  LazyPopup {
    id: gateAdvanced
    wanted: root.advancedSettingsOpen
    AdvancedSettings {
      id: advancedSettings
      open: gateAdvanced.open
      targetScreen: root.focusedMonitor
      appearanceValues: root.appearance
      onCloseRequested: root.advancedSettingsOpen = false
      onBackRequested: root.goBack("menu")
      onRequestMonitorEditor: root.swapTo("monitoreditor")
      // Monitor, Launcher, Terminal y Barra se configuran dentro de Ajustes
      // Avanzados; solo Idioma sigue abriendo su ventana (IPC).
      targetMonitor: root.targetMonitor
      resolvedMonitor: root.resolveMonitor()
      onMonitorChosen: (name) => root.setMonitor(name)
      onLanguageChosen: (code) => root.setLang(code)
      onAppearancePreviewChanged: (key, value) => root.applyAppearanceLive(key, value)
      onAppearanceValueCommitted: (key, value) => root.setAppearanceValue(key, value)
      onAppearanceToggleChanged: (key, value) => root.setAppearanceValue(key, value)
      // Marco de pantalla (Interfaz → Marco): mismo estado que el botón del
      // Menú (ver más abajo) y el IPC `corners toggle`.
      screenCorners: root.screenCorners
      onRequestCornersToggle: root.setScreenCorners(!root.screenCorners)
    }
  }

  // Sub-ventanas de Ajustes → General (mismo patrón que Monitor/Idioma):
  // cada una vuelve a Ajustes con la flecha ‹.
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
    // Este submenú describe únicamente la superficie BAR/ISLAS.
    // En Píldora la configuración de la interfaz vive en Ajustes avanzados.
    active: !Theme.pillMode
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
  // Mismo patrón que monitor/lang: una property "appearance" (objeto),
  // persistida en un cache JSON, cambiable en caliente por IPC. La
  // diferencia es que además de guardar el cache, cada cambio:
  //   1) se aplica al toque con `hyprctl keyword ...` (feedback
  //      instantáneo, sin tocar ningún archivo ni recargar nada)
  //   2) regenera ~/.config/hypr/theme.lua y ~/.config/hypr/layouts.lua,
  //      que tu hyprland.lua importa con require("theme") / require("layouts")
  //      para que el valor sobreviva a un reinicio real de Hyprland.
  //
  //   quickshell ipc -p .../shell.qml call -- appearance toggle
  //   quickshell ipc -p .../shell.qml call -- appearance get
  //   quickshell ipc -p .../shell.qml call -- appearance set gapsOut 10
  //   quickshell ipc -p .../shell.qml call -- appearance set blurEnabled true
  //   quickshell ipc -p .../shell.qml call -- appearance set layout master
  property var appearance: ({
    gapsIn: 3, gapsOut: 6, borderSize: 2,
    rounding: 10, roundingPower: 5,
    activeOpacity: 1.0, inactiveOpacity: 1.0,
    blurEnabled: true, blurSize: 3, blurPasses: 1,
    shadowEnabled: false, shadowRange: 3, shadowRenderPower: 1,
    animationsEnabled: true,
    layout: "dwindle"
  })
  property string appearanceCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-appearance.json"

  // Traduce cada clave del objeto "appearance" a la ruta de tabla
  // anidada que usa hl.config() en Lua (ej. decoration.blur.enabled).
  // Hyprland 0.55+ corre con configProvider: lua, así que el clásico
  // `hyprctl keyword <opcion> <valor>` viene deshabilitado ("unknown
  // request"); el reemplazo es `hyprctl eval '<código lua>'`, que
  // ejecuta directamente un hl.config({...}) equivalente.
  readonly property var appearanceLuaPath: ({
    gapsIn:            ["general", "gaps_in"],
    gapsOut:           ["general", "gaps_out"],
    borderSize:        ["general", "border_size"],
    rounding:          ["decoration", "rounding"],
    roundingPower:     ["decoration", "rounding_power"],
    activeOpacity:     ["decoration", "active_opacity"],
    inactiveOpacity:   ["decoration", "inactive_opacity"],
    blurEnabled:       ["decoration", "blur", "enabled"],
    blurSize:          ["decoration", "blur", "size"],
    blurPasses:        ["decoration", "blur", "passes"],
    shadowEnabled:     ["decoration", "shadow", "enabled"],
    shadowRange:       ["decoration", "shadow", "range"],
    shadowRenderPower: ["decoration", "shadow", "render_power"],
    animationsEnabled: ["animations", "enabled"]
  })

  // Arma un literal de tabla Lua anidada a partir de un path y un
  // valor. Ej: (["decoration","blur","enabled"], true) ->
  // "{ decoration = { blur = { enabled = true } } }"
  function buildLuaTable(path, value) {
    const v = (typeof value === "boolean") ? (value ? "true" : "false") : value
    let expr = String(v)
    for (let i = path.length - 1; i >= 0; i--) {
      expr = "{ " + path[i] + " = " + expr + " }"
    }
    return expr
  }

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
        // Asegura que theme.lua / layouts.lua existan siempre, incluso
        // en la primera corrida (sin cache todavía), para que el
        // require("theme") / require("layouts") de hyprland.lua no falle.
        root.writeThemeLua()
        root.writeLayoutsLua(root.appearance.layout)
      }
    }
  }

  Process {
    id: applyAppearanceKeyword
    property string cmd: ""
    command: ["bash", "-c", cmd]
    running: false
    stdout: SplitParser { onRead: line => console.log("[appearance] hyprctl:", line) }
    stderr: SplitParser { onRead: line => console.log("[appearance] hyprctl error:", line) }
  }

  // Preview instantáneo: NO toca disco, solo aplica en vivo vía
  // `hyprctl eval` (el reemplazo de `hyprctl keyword` en modo lua).
  // Se llama en cada movimiento del slider (onPreviewChanged).
  function applyAppearanceLive(key, value) {
    const path = root.appearanceLuaPath[key]
    if (!path) return
    const table = root.buildLuaTable(path, value)
    applyAppearanceKeyword.cmd = "hyprctl eval 'hl.config(" + table + ")'"
    applyAppearanceKeyword.running = false
    applyAppearanceKeyword.running = true
  }

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

  Process {
    id: saveThemeLua
    property string content: ""
    command: ["bash", "-c",
      "cat > '" + Quickshell.env("HOME") + "/.config/hypr/modules/appearance/autogen/theme.lua' << 'OOZE_LUA_EOF'\n" + content + "\nOOZE_LUA_EOF\n"]
    running: false
  }

  // Regenera ~/.config/hypr/theme.lua a partir de root.appearance.
  // Es un archivo generado: no se edita a mano, se pisa cada vez.
  function writeThemeLua() {
    const a = root.appearance
    const lua =
      "-- Auto-generado por OozeShell (APPEARANCE). No editar a mano.\n" +
      "-- Se regenera cada vez que cambiás algo desde el panel de apariencia.\n" +
      "return {\n" +
      "    gaps_in = " + a.gapsIn + ",\n" +
      "    gaps_out = " + a.gapsOut + ",\n" +
      "    border_size = " + a.borderSize + ",\n" +
      "    rounding = " + a.rounding + ",\n" +
      "    rounding_power = " + a.roundingPower + ",\n" +
      "    active_opacity = " + a.activeOpacity + ",\n" +
      "    inactive_opacity = " + a.inactiveOpacity + ",\n" +
      "    animations = " + (a.animationsEnabled ? "true" : "false") + ",\n" +
      "    blur = {\n" +
      "        enabled = " + (a.blurEnabled ? "true" : "false") + ",\n" +
      "        size = " + a.blurSize + ",\n" +
      "        passes = " + a.blurPasses + ",\n" +
      "    },\n" +
      "    shadow = {\n" +
      "        enabled = " + (a.shadowEnabled ? "true" : "false") + ",\n" +
      "        range = " + a.shadowRange + ",\n" +
      "        render_power = " + a.shadowRenderPower + ",\n" +
      "    },\n" +
      "}\n"
    saveThemeLua.content = lua
    saveThemeLua.running = false
    saveThemeLua.running = true
  }

  Process {
    id: saveLayoutsLua
    property string content: ""
    command: ["bash", "-c",
      "cat > '" + Quickshell.env("HOME") + "/.config/hypr/modules/appearance/autogen/layouta.lua' << 'OOZE_LUA_EOF'\n" + content + "\nOOZE_LUA_EOF\n"]
    running: false
  }

  // Regenera ~/.config/hypr/layouts.lua con el layout por defecto
  // para los 10 workspaces (mismo criterio que tu loop de
  // `for i = 1, 10 do hl.workspace_rule(...) end`).
  function writeLayoutsLua(layoutName) {
    const lua =
      "-- Auto-generado por OozeShell (APPEARANCE). No editar a mano.\n" +
      "return {\n" +
      "    layout = \"" + layoutName + "\",\n" +
      "}\n"
    saveLayoutsLua.content = lua
    saveLayoutsLua.running = false
    saveLayoutsLua.running = true
  }

  // Commit de un valor: actualiza el estado, lo aplica en vivo (por
  // si el commit llega sin preview previo, ej. desde IPC) y persiste
  // cache + theme.lua. Se llama al soltar el slider, o al tocar un
  // toggle (que no tiene "arrastre", así que aplica y persiste junto).
  function setAppearanceValue(key, value) {
    const updated = Object.assign({}, root.appearance)
    updated[key] = value
    root.appearance = updated

    applyAppearanceLive(key, value)
    writeAppearanceCache()
    writeThemeLua()
  }

  Process {
    id: applyLayoutKeyword
    property string cmd: ""
    command: ["bash", "-c", cmd]
    running: false
    stdout: SplitParser { onRead: line => console.log("[layout] hyprctl:", line) }
    stderr: SplitParser { onRead: line => console.log("[layout] hyprctl error:", line) }
  }

  Process {
    id: notifyLayoutChange
    property string cmd: ""
    command: ["bash", "-c", cmd]
    running: false
  }

  // Cambia el layout por defecto de los 10 workspaces, tanto en vivo
  // (hyprctl keyword, se ve al toque) como persistido (layouts.lua).
  // Como el bind SUPER+K lee el layout en vivo del workspace activo
  // (hl.get_active_workspace().tiled_layout), no hace falta sincronizar
  // nada aparte: al aplicar acá con hyprctl keyword, la próxima vez
  // que se apriete SUPER+K va a ciclar a partir del layout real.
  function setLayout(layoutName) {
    const updated = Object.assign({}, root.appearance)
    updated.layout = layoutName
    root.appearance = updated

    // Un solo hyprctl eval con un for de Lua, en vez de 10 llamadas
    // separadas: mismo criterio que tu loop `for i = 1, 10 do
    // hl.workspace_rule(...) end` en hyprland.lua, pero disparado
    // en caliente vía eval.
    applyLayoutKeyword.cmd =
      "hyprctl eval 'for i = 1, 10 do hl.workspace_rule({ workspace = tostring(i), layout = \"" +
      layoutName + "\" }) end'"
    applyLayoutKeyword.running = false
    applyLayoutKeyword.running = true

    writeAppearanceCache()
    writeLayoutsLua(layoutName)

    // Mismo mecanismo de notificación que ya usa el bind SUPER+K.
    notifyLayoutChange.cmd =
      "quickshell ipc -p ~/.config/hypr/OozeShell/shell.qml call -- notify show 'Layout: " + layoutName + "'"
    notifyLayoutChange.running = false
    notifyLayoutChange.running = true
  }

  IpcHandler {
    target: "appearance"
    function toggle(): void { root.togglePopup("appearance") }
    function get(): string { return JSON.stringify(root.appearance) }
    // set <key> <value>  -- ej: set gapsOut 10 / set blurEnabled true / set shadowRange 8 / set layout master
    function set(key: string, value: string): void {
      if (key === "layout") { root.setLayout(value); return }
      if (key === "blurEnabled" || key === "animationsEnabled" || key === "shadowEnabled") {
        root.setAppearanceValue(key, (value === "true" || value === "1"))
      } else {
        root.setAppearanceValue(key, parseFloat(value))
      }
    }
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
      "WP=$(cat ~/.cache/awww/last 2>/dev/null); " +
      "if [ -n \"$WP\" ] && [ -f \"$WP\" ]; then " +
      "  matugen image \"$WP\" --source-color-index 0 --json hex | sed -n '/^{/,/^}/p' > /tmp/matugen-colors.json; " +
      "fi"
    ]
    running: true
  }


  IpcHandler {
    target: "toggleWalls"
    function handle() { root.wallsOpen = !root.wallsOpen }
  }


  Walls {
    id: walls
    open: root.wallsOpen
    currentIndex: root.currentWallIndex
    targetScreen: root.focusedMonitor
    onCurrentIndexChanged: root.currentWallIndex = walls.currentIndex
    onCloseRequested: root.wallsOpen = false
    onColorsReloaded: Theme.reload()
    // Theme.wallpaperChanging es la misma bandera que barModule.wallpaperChanging
    // (línea de arriba, `wallpaperChanging: walls.changing`) pero accesible desde
    // CUALQUIER popup (FusedWindow), no solo desde la barra: mientras dura, los
    // paneles abiertos se dibujan flotantes en vez de colgar de una barra oculta.
    onChangingChanged: Theme.wallpaperChanging = walls.changing
  }

  // Ejemplos:
  //   quickshell ipc -p .../shell.qml call -- notify toggle
  //   quickshell ipc -p .../shell.qml call -- notify toggleDnd
  //   quickshell ipc -p .../shell.qml call -- notify show 'Layout: master'
  IpcHandler {
    target: "notify"
    function toggle(): void { root.togglePopup("notify") }
    // Toast local (lo usa setLayout() más arriba). No se guarda en el historial.
    function show(text: string): void { NotificationsBackend.pushLocal("OozeShell", text) }
    function toggleDnd(): void { NotificationsBackend.toggleDnd() }
    function enableDnd(): void { NotificationsBackend.dnd = true }
    function disableDnd(): void { NotificationsBackend.dnd = false }
    function isDnd(): bool { return NotificationsBackend.dnd }
    function clear(): void { NotificationsBackend.clearAll() }
  }

  Notify {
    id: notify
    open: root.notifyOpen
    targetScreen: root.focusedMonitor
    onCloseRequested: root.notifyOpen = false
  }

  // ─── Calendario con ToDo ─────────────────────────────────────────
  // Clic DERECHO en el reloj (barra clásica / islas). En modo Píldora es una
  // sección del Dashboard (DASHBOARD/DashboardCalendar.qml); ambos usan
  // AGENDA/AgendaView.qml y las mismas tareas (AGENDA/TodoBackend.qml).
  //
  //   quickshell ipc -p .../shell.qml call -- agenda toggle
  //   quickshell ipc -p .../shell.qml call -- agenda open
  //   quickshell ipc -p .../shell.qml call -- agenda close
  // En modo Píldora abre / cierra la sección Calendario del Dashboard.
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

  IpcHandler {
    target: "keybinds"
    // Ahora es un popup de la barra (FusedPanel): abrirlo cierra los demás
    function toggle(): void { root.togglePopup("keybinds") }
  }

  // ─── Idioma de teclado ───────────────────────────────────────────
  // La forma recomendada de que ALT+SHIFT cambie de layout es nativa de
  // Hyprland (no necesita este IPC ni QML: lo hace libinput/xkb solo,
  // y dispara el mismo evento "activelayout" que ya sincroniza el
  // indicador ESP/ENG de la barra). En el input{} de hyprland.conf:
  //
  //   input {
  //     kb_options = grp:alt_shift_toggle
  //   }
  //
  // Si ya usás kb_options para otra cosa, separalas con coma
  // (ej. "caps:escape,grp:alt_shift_toggle"). Este IpcHandler queda
  // como alternativa manual/de prueba, o por si preferís atarlo vos
  // mismo a otra combinación desde Hyprland:
  //   quickshell ipc -p .../shell.qml call -- keyboardlayout next
  IpcHandler {
    target: "keyboardlayout"
    function next(): void { KeyboardLayout.next() }
  }

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

  // quickshell ipc -p .../shell.qml call -- bluetooth toggle
  IpcHandler {
    target: "bluetooth"
    function toggle(): void { root.togglePopup("bluetooth") }
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
  // El panel es un popup exclusivo más (mismo sistema que menu/notify/
  // network/mpris); el OSD es independiente y siempre está montado,
  // como NotifToasts, y aparece solo mientras AudioBackend lo pide.
  //
  //   quickshell ipc -p .../shell.qml call -- audio toggle
  //   quickshell ipc -p .../shell.qml call -- audio raise
  //   quickshell ipc -p .../shell.qml call -- audio lower
  //   quickshell ipc -p .../shell.qml call -- audio mute
  //   quickshell ipc -p .../shell.qml call -- audio micToggle
  //
  // Apuntá los binds de volumen de Hyprland (y lo que antes llamaba a
  // swayosd-client) acá: el OSD que dispara es el de AUDIO/AudioOSD.qml,
  // no hace falta correr swayosd-server nunca más.
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
  // Aviso flotante al activar/desactivar Caps Lock (CAPS/CapsOSD.qml).
  // Prueba sin teclado:
  //   quickshell ipc -p .../shell.qml call -- caps show true|false
  CapsOSD {
    id: capsOsd
    targetScreen: root.focusedMonitor
  }

  IpcHandler {
    target: "caps"
    function show(on: bool): void { capsOsd.show(on) }
  }

  // ─── OSD de idioma del teclado (layout xkb) ─────────────────────
  // Píldora a la izquierda, mismo look que el de Caps. La dispara solo
  // KeyboardLayout.layoutSwitched; no genera notificaciones.
  // Prueba sin teclado:
  //   quickshell ipc -p .../shell.qml call -- layoutosd show English
  LayoutOSD {
    id: layoutOsd
    targetScreen: root.focusedMonitor
  }

  IpcHandler {
    target: "layoutosd"
    function show(name: string): void { layoutOsd.show(name, KeyboardLayout.labelFor(name)) }
  }

  // ─── Overview (vista general de los workspaces) ─────────────────
  // Botón junto al reloj de la barra. Cuelga de la barra como los demás
  // popups (excluyente con ellos) y se maneja con mouse o teclado; ver
  // OVERVIEW/Overview.qml para las teclas.
  //
  //   quickshell ipc -p .../shell.qml call -- overview toggle
  //   quickshell ipc -p .../shell.qml call -- overview open
  //   quickshell ipc -p .../shell.qml call -- overview close
  IpcHandler {
    target: "overview"
    // Overview es una superficie propia de la barra. En Píldora los
    // workspaces ya tienen representación compacta en PILL, por lo que
    // no abrimos una segunda tarjeta que rompa la composición.
    function toggle(): void { if (!Theme.pillMode) root.togglePopup("overview") }
    function open(): void { if (!Theme.pillMode) root.openPopup("overview") }
    function close(): void { root.overviewOpen = false }
  }

  LazyLoader {
    active: !Theme.pillMode
    Overview {
      id: overview
      open: root.overviewOpen
      targetScreen: root.focusedMonitor
      onCloseRequested: root.overviewOpen = false
    }
  }

  // ─── Launcher (reemplaza el launcher de rofi) ───────────────────
  // Apps / Ventanas / Ejecutar / Archivos en un solo panel. Cuelga de la
  // barra como los demás popups (excluyente con ellos); ver
  // Launcher/Launcher.qml para las teclas.
  //
  //   quickshell ipc -p .../shell.qml call -- launcher toggle
  //   quickshell ipc -p .../shell.qml call -- launcher open apps|windows|run|files
  //   quickshell ipc -p .../shell.qml call -- launcher close
  // Bindealo en Hyprland en vez del script de rofi. `open windows` /
  // `open run` / `open files` reemplazan a `rofi -show window|run|filebrowser`.
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      root.launcherStartMode = "apps"
      root.togglePopup("launcher")
    }
    function open(mode: string): void {
      const ok = ["apps", "windows", "run", "files"]
      root.launcherStartMode = ok.indexOf(mode) >= 0 ? mode : "apps"
      root.openPopup("launcher")
    }
    function close(): void { root.launcherOpen = false }
  }

  LazyPopup {
    id: gateLauncher
    wanted: root.launcherOpen
    openDelay: 50     // el launcher tiene que sentirse inmediato
    Launcher {
      id: launcher
      open: gateLauncher.open
      startMode: root.launcherStartMode
      targetScreen: root.focusedMonitor
      onCloseRequested: root.launcherOpen = false
    }
  }

  // ─── Nix Search (reemplaza el script de rofi + nix-search) ──────
  // Busca en nixpkgs mientras escribís. Ver NixSearch/NixSearch.qml.
  //
  //   quickshell ipc -p .../shell.qml call -- nixsearch toggle
  //   quickshell ipc -p .../shell.qml call -- nixsearch open [consulta]
  //   quickshell ipc -p .../shell.qml call -- nixsearch close
  IpcHandler {
    target: "nixsearch"
    function toggle(): void {
      root.nixStartQuery = ""
      root.togglePopup("nixsearch")
    }
    function open(query: string): void {
      root.nixStartQuery = query
      root.openPopup("nixsearch")
    }
    function close(): void { root.nixSearchOpen = false }
  }

  LazyPopup {
    id: gateNix
    wanted: root.nixSearchOpen
    openDelay: 50
    NixSearch {
      id: nixSearch
      open: gateNix.open
      startQuery: root.nixStartQuery
      targetScreen: root.focusedMonitor
      onCloseRequested: root.nixSearchOpen = false
    }
  }

  // ─── Capturas de pantalla (solo IPC, sin panel) ──────────────────
  // Ver SCREENSHOT/ScreenshotBackend.qml y ScreenshotFreeze.qml (congela la
  // pantalla mientras eliges el área). El marco de selección usa
  // Theme.primary, así que sigue el color del wallpaper actual igual que
  // el resto del shell — pero no hay ningún botón para esto en la UI:
  // asigná estos comandos a tus binds de Hyprland (Print, Shift+Print, etc).
  //   quickshell ipc -p .../shell.qml call -- screenshot areaCopy
  //   quickshell ipc -p .../shell.qml call -- screenshot fullSave
  //   quickshell ipc -p .../shell.qml call -- screenshot areaSave
  IpcHandler {
    target: "screenshot"
    function areaCopy(): void { ScreenshotBackend.areaCopy() }
    function fullSave(): void { ScreenshotBackend.fullSave() }
    function areaSave(): void { ScreenshotBackend.areaSave() }
  }

  // Selector de área con la pantalla congelada (areaCopy / areaSave).
  ScreenshotFreeze {}

  // ─── Menú de energía (reemplaza el powermenu.sh de rofi) ────────
  //   quickshell ipc -p .../shell.qml call -- powermenu toggle
  //   quickshell ipc -p .../shell.qml call -- powermenu open
  //   quickshell ipc -p .../shell.qml call -- powermenu close
  // Apuntá acá tu bind de Hyprland (SUPER SHIFT M) en vez de al script.
  IpcHandler {
    target: "powermenu"
    function toggle(): void {
      root.closeAllPopups()
      if (!root.powerOpen) root.focusedMonitor = root.resolveMonitor()
      root.powerOpen = !root.powerOpen
    }
    function open(): void {
      root.closeAllPopups()
      root.focusedMonitor = root.resolveMonitor()
      root.powerOpen = true
    }
    function close(): void { root.powerOpen = false }
  }

  PowerMenu {
    id: powerMenu
    open: root.powerOpen
    targetScreen: root.focusedMonitor
    onCloseRequested: root.powerOpen = false
  }

  // ─── Pantalla de bloqueo (reemplaza a hyprlock) ─────────────────
  // Ver LOCK/LockScreen.qml. Bloquea al instante con el wallpaper del
  // momento como fondo; solo se sale con la contraseña (no hay IPC de
  // desbloqueo a propósito). Sirve tanto para hypridle (lock_cmd) como
  // para un bind de teclado:
  //   quickshell ipc -p .../shell.qml call -- lock lock
  //   quickshell ipc -p .../shell.qml call -- lock locked
  LockScreen {
    id: lockScreen
  }

  IpcHandler {
    target: "lock"
    function lock(): void {
      // Cierra lo que haya abierto para que no reaparezca al desbloquear
      root.closeAllPopups()
      root.powerOpen = false
      root.wallsOpen = false
      lockScreen.lock()
    }
    function locked(): bool { return lockScreen.locked }
  }

  LazyLoader {
    active: !Theme.pillMode
    Menu {
      id: menu
      open: root.menuOpen
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