// AudioControl — volumen del dispositivo de salida por defecto, vía wpctl
// (PipeWire / WirePlumber). Solo consulta mientras `active` (menú abierto)
// y no mientras se arrastra el slider, para que no "salte" el control.
import QtQuick
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property bool dragging: false
  property real volume: 0        // 0..1
  property bool muted: false

  readonly property string icon: {
    if (root.muted || root.volume <= 0) return "󰝟"
    if (root.volume < 0.34) return "󰕿"
    if (root.volume < 0.67) return "󰖀"
    return "󰕾"
  }

  // "Volume: 0.45" o "Volume: 0.45 [MUTED]"
  function parse(line) {
    const m = line.match(/Volume:\s*([0-9.]+)/)
    if (!m) return
    if (!root.dragging) root.volume = Math.min(1, parseFloat(m[1]))
    root.muted = line.indexOf("[MUTED]") !== -1
  }

  function refresh() {
    if (!getProc.running) getProc.running = true
  }

  // Durante el arrastre solo actualiza el valor local y agenda el envío
  // (throttle: como mucho un wpctl cada ~60 ms)
  function setVolume(v) {
    root.volume = Math.max(0, Math.min(1, v))
    if (!sendTimer.running) sendTimer.start()
  }

  // Envía el valor final inmediatamente (al soltar / rueda)
  function commit() {
    sendTimer.stop()
    root.send()
  }

  function send() {
    setProc.target = root.volume
    setProc.running = false
    setProc.running = true
    // Mover el slider con el audio silenciado lo reactiva
    if (root.muted && root.volume > 0) {
      root.muted = false
      unmuteProc.running = false
      unmuteProc.running = true
    }
  }

  function toggleMute() {
    muteProc.running = false
    muteProc.running = true
  }

  Process {
    id: getProc
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: false
    stdout: SplitParser { onRead: line => root.parse(line) }
  }

  Process {
    id: setProc
    property real target: 0
    // -l 1.0: nunca pasa de 100 %
    command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", target.toFixed(2)]
    running: false
  }

  Process {
    id: unmuteProc
    command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]
    running: false
  }

  Process {
    id: muteProc
    command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    running: false
    onRunningChanged: { if (!running) refreshTimer.restart() }
  }

  Timer { id: sendTimer; interval: 60; repeat: false; onTriggered: root.send() }
  Timer { id: refreshTimer; interval: 120; repeat: false; onTriggered: root.refresh() }

  Timer {
    interval: 1200
    running: root.active && !root.dragging
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
