// DockBackend — apps "fijadas" al dock (favoritas): quedan como
// lanzadores aunque se cierren. Se fijan/desfijan con clic derecho sobre
// un ícono del dock (ver DOCK/Dock.qml).
//
// Persistencia aparte de ui.json, mismo patrón que targetMonitor/currentLang
// /screenCorners en shell.qml: un archivo de texto simple (un appId por
// línea), cargado una vez al arrancar y reescrito entero en cada cambio.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var pinnedApps: []   // [appId, …] en el orden en que se fijaron
  readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/oozeshell-dock-pins"

  function isPinned(appId) {
    return appId !== "" && root.pinnedApps.indexOf(appId) >= 0
  }

  function togglePin(appId) {
    if (!appId || appId === "") return
    const list = root.pinnedApps.slice()
    const i = list.indexOf(appId)
    if (i >= 0) list.splice(i, 1)
    else list.push(appId)
    root.pinnedApps = list
    root.save()
  }

  function save() {
    saveProc.text = root.pinnedApps.join("\n")
    saveProc.running = false
    saveProc.running = true
  }

  Process {
    id: loadProc
    command: ["bash", "-c", "cat '" + root.cacheFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const lines = loadProc.buffer.split("\n").map(l => l.trim()).filter(l => l !== "")
      loadProc.buffer = ""
      root.pinnedApps = lines
    }
  }

  Process {
    id: saveProc
    property string text: ""
    command: ["bash", "-c",
      "mkdir -p \"$(dirname '" + root.cacheFile + "')\" && cat > '" + root.cacheFile + "' << 'OOZE_EOF'\n" + text + "\nOOZE_EOF\n"]
    running: false
  }
}
