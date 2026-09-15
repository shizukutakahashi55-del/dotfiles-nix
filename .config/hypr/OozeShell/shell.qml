// OozeShell Wallpapers and More

import Quickshell
import Quickshell.Io
import "./WALLS"
import "./NOTIFY"
import "./MONITOR"
import "./Keybinds"

ShellRoot {
  id: root

  property bool wallsOpen:     false
  property bool keybindsOpen:  false
  property int  currentWallIndex: 0
  property bool monitorPickerOpen: false

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
  property string monitorCacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-monitor"

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
    saveMonitor.value = name
    saveMonitor.running = false
    saveMonitor.running = true
  }

  IpcHandler {
    target: "monitor"
    function set(name: string): void { root.setMonitor(name) }
    function get(): string { return root.targetMonitor }
    function togglePicker(): void { root.monitorPickerOpen = !root.monitorPickerOpen }
    // Lista las pantallas conectadas ahora mismo, así no hay que
    // adivinar el nombre exacto (DP-3, HDMI-A-1, etc).
    function list(): string {
      return Quickshell.screens.map(s => s.name).join(", ")
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
    targetScreen: root.targetMonitor
    onCurrentIndexChanged: root.currentWallIndex = walls.currentIndex
    onCloseRequested: root.wallsOpen = false
  }

  Notify {
    id: notify
    targetScreen: root.targetMonitor
  }

  MonitorSelect {
    id: monitorSelect
    open: root.monitorPickerOpen
    current: root.targetMonitor
    onCloseRequested: root.monitorPickerOpen = false
    onMonitorChosen: (name) => root.setMonitor(name)
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
