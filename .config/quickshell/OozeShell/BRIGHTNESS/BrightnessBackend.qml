// BrightnessBackend — brillo de la pantalla vía `brightnessctl`.
// Si `brightnessctl` no existe o no hay backlight controlable (de
// escritorio, por ejemplo), `available` queda en false y el slider no se
// muestra.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool watch: false
  property bool dragging: false

  property bool available: false
  property real brightness: 1     // 0..1

  // `brightnessctl -m` → "clase,dispositivo,actual,PORC%,max" (una línea)
  function parseInfo(line) {
    const parts = line.split(",")
    if (parts.length < 4) return
    const pct = parseFloat(parts[3].replace("%", ""))
    if (isNaN(pct)) return
    root.available = true
    if (!root.dragging) root.brightness = Math.max(0, Math.min(1, pct / 100))
  }

  function refresh() { if (!getProc.running) getProc.running = true }

  Process {
    id: getProc
    command: ["brightnessctl", "-m"]
    running: false
    property bool gotLine: false
    stdout: SplitParser { onRead: line => { getProc.gotLine = true; root.parseInfo(line) } }
    onRunningChanged: {
      if (running) { gotLine = false; return }
      if (!gotLine) root.available = false
    }
  }

  function setBrightness(v) {
    root.brightness = Math.max(0, Math.min(1, v))
    if (!sendTimer.running) sendTimer.start()
  }
  function commit() { sendTimer.stop(); root.send() }

  function send() {
    setProc.pct = Math.round(root.brightness * 100)
    setProc.running = false
    setProc.running = true
  }

  function stepBrightness(delta) {
    root.setBrightness(root.brightness + delta)
    root.commit()
  }

  Process {
    id: setProc
    property int pct: 100
    command: ["brightnessctl", "set", pct + "%"]
    running: false
  }

  Timer { id: sendTimer; interval: 60; repeat: false; onTriggered: root.send() }

  Timer {
    interval: 2000
    running: root.watch
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onWatchChanged: { if (root.watch) root.refresh() }
}
