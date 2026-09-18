// OozeShell Wallpapers and More

import Quickshell
import Quickshell.Io
import "./WALLS"
import "./Keybinds"
import "./LANG"

ShellRoot {
  id: root

  property bool wallsOpen:     false
  property bool mprisOpen:     false
  property bool keybindsOpen:  false
  property int  currentWallIndex: 0
  property bool monitorPickerOpen: false
  property bool langPickerOpen: false

  // ─── Selector de monitor ────────────────────────────────────────
  // Un solo lugar para decidir en qué pantalla vive el shell.
  // Walls/Notify/Mpris leen esta property en vez de tener el nombre
  // de la pantalla hardcodeado cada uno. Se persiste en disco para
  // que sobreviva a un reinicio de Quickshell, y se puede cambiar
  // en caliente por IPC sin editar QML ni reiniciar nada:
  //   quickshell ipc -p .../shell.qml call -- monitor set DP-3
  //   quickshell ipc -p .../shell.qml call -- monitor list
  //   quickshell ipc -p .../shell.qml call -- monitor get
  property string targetMonitor: "DP-3"

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
    function togglePicker(): void { root.langPickerOpen = !root.langPickerOpen }
    function list(): string {
      return Translations.availableLanguages.map(l => l.code + " (" + l.name + ")").join(", ")
    }
  }

  LanguagePicker {
    id: languagePicker
    open: root.langPickerOpen
    current: root.currentLang
    onCloseRequested: root.langPickerOpen = false
    onLanguageChosen: (code) => root.setLang(code)
  }

  // Al arrancar, regenera /tmp/matugen-colors.json a partir del
  // último wallpaper aplicado (guardado por Walls.qml). Antes leía
  // ~/.cache/awww/last (daemon de Hyprland); ahora usa la ruta
  // propia de OozeShell-KDE. --json hex no aplica templates del
  // config.toml, así que aquí no hace falta pasar -c, pero se lo
  // damos igual por consistencia con el resto de llamadas.
  Process {
    id: initColors
    command: ["bash", "-c",
      "WP=$(cat ~/.cache/oozeshell-kde/last-wallpaper 2>/dev/null); " +
      "if [ -n \"$WP\" ] && [ -f \"$WP\" ]; then " +
      "  matugen -c ~/.config/matugen/config-kde.toml image \"$WP\" --source-color-index 0 --json hex | sed -n '/^{/,/^}/p' > /tmp/matugen-colors.json; " +
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
    targetScreen: root.targetMonitor
    onCurrentIndexChanged: root.currentWallIndex = walls.currentIndex
    onCloseRequested: root.wallsOpen = false
  }

  IpcHandler {
    target: "keybinds"
    function toggle() { root.keybindsOpen = !root.keybindsOpen }
  }

  Keybinds {
    id: keybinds
    open: root.keybindsOpen
    onCloseRequested: root.keybindsOpen = false
  }

  
}
