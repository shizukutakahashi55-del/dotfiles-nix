// AudioBackend 
//
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
  id: root

  // ─── Quién está mirando ────────────────────────────────────────
  // Contador de "miradores" (AudioMenu, DashboardAudio…). Antes era un bool
  // compartido: el dashboard (Loader asíncrono) y AudioMenu se pisaban y uno
  // apagaba el escaneo del mixer mientras el otro seguía abierto.
  property int watchers: 0
  readonly property bool menuWatch: watchers > 0
  function acquireWatch() { root.watchers = root.watchers + 1 }
  function releaseWatch() { root.watchers = Math.max(0, root.watchers - 1) }
  property bool dragging: false
  property bool micDragging: false

  // ─── Estado: salida (sink) por defecto ──────────────────────────
  property real volume: 0        // 0..1
  property bool muted: false

  // ─── Estado: entrada (source/mic) por defecto ───────────────────
  property real micVolume: 0     // 0..1
  property bool micMuted: false

  // ─── Listas de dispositivos (solo mientras el panel está abierto)
  property var sinks: []         // [{ id, name, volume, muted, active }]
  property var sources: []
  property string sinksKey: ""
  property string sourcesKey: ""

  readonly property string icon: {
    if (root.muted || root.volume <= 0) return "󰝟"
    if (root.volume < 0.34) return "󰕿"
    if (root.volume < 0.67) return "󰖀"
    return "󰕾"
  }
  readonly property string micIcon: root.micMuted ? "󰍭" : "󰍬"

  // ═══════════════════════════════════════════════════════════════
  // OSD (reemplaza swayosd-client)
  // ═══════════════════════════════════════════════════════════════
  property bool osdVisible: false
  property string osdKind: "volume"   // "volume" | "mic"
  property real osdValue: 0
  property bool osdMuted: false

  function showOsd(kind, value, isMuted) {
    root.osdKind = kind
    root.osdValue = value
    root.osdMuted = isMuted
    root.osdVisible = true
    osdHideTimer.restart()
  }
  function hideOsd() { root.osdVisible = false }

  Timer { id: osdHideTimer; interval: 1600; repeat: false; onTriggered: root.osdVisible = false }

  // ═══════════════════════════════════════════════════════════════
  // VOLUMEN (sink / source por defecto)
  // ═══════════════════════════════════════════════════════════════

  function parseVol(line, isMic) {
    const m = line.match(/Volume:\s*([0-9.]+)/)
    if (!m) return
    const v = Math.min(1, parseFloat(m[1]))
    const mu = line.indexOf("[MUTED]") !== -1
    if (isMic) {
      if (!root.micDragging) root.micVolume = v
      root.micMuted = mu
    } else {
      if (!root.dragging) root.volume = v
      root.muted = mu
    }
  }

  function refreshVolumes() {
    if (!getSinkProc.running) getSinkProc.running = true
    if (!getSourceProc.running) getSourceProc.running = true
  }

  Process {
    id: getSinkProc
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: false
    stdout: SplitParser { onRead: line => root.parseVol(line, false) }
  }
  Process {
    id: getSourceProc
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
    running: false
    stdout: SplitParser { onRead: line => root.parseVol(line, true) }
  }

  // ── Salida ────────────────────────────────────────────────────
  function setVolume(v) {
    root.volume = Math.max(0, Math.min(1, v))
    if (!sendSinkTimer.running) sendSinkTimer.start()
  }
  function commit() { sendSinkTimer.stop(); root.sendSink() }

  function sendSink() {
    setSinkProc.target = root.volume
    setSinkProc.running = false
    setSinkProc.running = true
    if (root.muted && root.volume > 0) {
      root.muted = false
      unmuteSinkProc.running = false
      unmuteSinkProc.running = true
    }
  }

  function toggleMute() {
    muteSinkProc.running = false
    muteSinkProc.running = true
  }

  // Como cycleProfile() en LeftModules: actualiza optimista y muestra
  // el OSD ya, el poll de abajo confirma (o corrige) el valor real.
  function toggleMuteOsd() {
    root.toggleMute()
    root.muted = !root.muted
    root.showOsd("volume", root.volume, root.muted)
  }

  // Usado por el scroll del pill y por el IpcHandler "audio" (binds)
  function stepVolume(delta) {
    root.setVolume(root.volume + delta)
    root.commit()
    root.showOsd("volume", root.volume, root.muted)
  }

  // ── Entrada / micrófono ─────────────────────────────────────────
  function setMicVolume(v) {
    root.micVolume = Math.max(0, Math.min(1, v))
    if (!sendSourceTimer.running) sendSourceTimer.start()
  }
  function commitMic() { sendSourceTimer.stop(); root.sendSource() }

  function sendSource() {
    setSourceProc.target = root.micVolume
    setSourceProc.running = false
    setSourceProc.running = true
    if (root.micMuted && root.micVolume > 0) {
      root.micMuted = false
      unmuteSourceProc.running = false
      unmuteSourceProc.running = true
    }
  }

  function toggleMicMute() {
    muteSourceProc.running = false
    muteSourceProc.running = true
  }

  function toggleMicMuteOsd() {
    root.toggleMicMute()
    root.micMuted = !root.micMuted
    root.showOsd("mic", root.micVolume, root.micMuted)
  }

  function stepMicVolume(delta) {
    root.setMicVolume(root.micVolume + delta)
    root.commitMic()
    root.showOsd("mic", root.micVolume, root.micMuted)
  }

  Process { id: setSinkProc;   property real target: 0
    command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", target.toFixed(2)]; running: false }
  Process { id: setSourceProc; property real target: 0
    command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", target.toFixed(2)]; running: false }
  Process { id: unmuteSinkProc;   command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]; running: false }
  Process { id: unmuteSourceProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"]; running: false }
  Process {
    id: muteSinkProc
    command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    running: false
    onRunningChanged: { if (!running) refreshTimer.restart() }
  }
  Process {
    id: muteSourceProc
    command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
    running: false
    onRunningChanged: { if (!running) refreshTimer.restart() }
  }

  Timer { id: sendSinkTimer;   interval: 60;  repeat: false; onTriggered: root.sendSink() }
  Timer { id: sendSourceTimer; interval: 60;  repeat: false; onTriggered: root.sendSource() }
  Timer { id: refreshTimer;    interval: 120; repeat: false; onTriggered: root.refreshVolumes() }

  // Siempre activo: el pill de la barra muestra el % todo el tiempo
  // (mismo criterio que el perfil de energía en LeftModules, cada 5s;
  // acá 1.5s porque el volumen cambia más seguido y hay que verlo
  // llegar de otras apps, ej. pavucontrol o media keys de otra app).
  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshVolumes()
  }

  // ═══════════════════════════════════════════════════════════════
  // DISPOSITIVOS + MIXER (wpctl status) — solo con el panel abierto
  // ═══════════════════════════════════════════════════════════════
  // "Streams:" son los flujos de reproducción por app (Firefox, Spotify,
  // mpv…) que expone wpctl. 

  function applyStatus(lines) {
    let section = ""
    const sinksArr = []
    const sourcesArr = []
    // │  *   45. Nombre del dispositivo   [vol: 0.42]
    // │      46. Otro dispositivo         [vol: 1.00 MUTED]
    const devRe = /^[\s│]*(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:\s*([0-9.]+)\s*(MUTED)?\]\s*$/

    const hdrRe = /(?:[├└]─|^)\s*(Devices|Sinks|Sources|Filters|Streams):\s*$/
    for (const raw of lines) {
      const h = raw.match(hdrRe)
      if (h) {
        section = h[1] === "Sinks" ? "sinks" : h[1] === "Sources" ? "sources" : ""
        continue
      }
      // Cabeceras de nivel superior ("Audio", "Video", "Settings")
      if (/^(Audio|Video|Settings)\s*$/.test(raw)) { section = ""; continue }
      if (section === "") continue

      const m = raw.match(devRe)
      if (!m) continue

      const entry = {
        id: parseInt(m[2]),
        name: m[3].trim(),
        volume: parseFloat(m[4]),
        muted: !!m[5],
        active: m[1] === "*"
      }
      if (section === "sinks") sinksArr.push(entry)
      else if (section === "sources") sourcesArr.push(entry)
    }

    const sKey = sinksArr.map(d => d.id + "|" + d.active + "|" + Math.round(d.volume * 20) + "|" + d.muted).join(";")
    if (sKey !== root.sinksKey) { root.sinksKey = sKey; root.sinks = sinksArr }

    const rKey = sourcesArr.map(d => d.id + "|" + d.active + "|" + Math.round(d.volume * 20) + "|" + d.muted).join(";")
    if (rKey !== root.sourcesKey) { root.sourcesKey = rKey; root.sources = sourcesArr }
  }

  Process {
    id: statusProc
    command: ["wpctl", "status"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => statusProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      root.applyStatus(lines)
    }
  }

  function refreshDevices() { if (!statusProc.running) statusProc.running = true }

  // ═══════════════════════════════════════════════════════════════
  // MIXER POR APP — API nativa de PipeWire (no wpctl)
  // ═══════════════════════════════════════════════════════════════
  // Cada app que reproduce audio es un nodo "Stream/Output/Audio". 

  property var streamNodes: []        // [PwNode, …]
  property string streamNodesKey: ""

  // Sin esto PipeWire no "bindea" los nodos: node.properties y node.audio
  // quedan vacíos/null (mismo motivo que en PrivacyBackend).
  PwObjectTracker { objects: Pipewire.nodes.values }

  function nodeProp(node, key) {
    const p = node ? node.properties : null
    return (p && p[key] !== undefined) ? String(p[key]) : ""
  }

  // ── Salidas virtuales de OozeAudio (pw-loopback) ────────────────
  // El stream que aparece acá para cada salida virtual es el lado
  // "playback.ooze_<nombre>" del loopback.
  
  function isOozeLoopback(node) {
    const n = root.nodeProp(node, "node.name")
    return /^(playback\.)?ooze_/i.test(n)
  }

  // "playback.ooze_discord" / "ooze_my_music" → "Ooze_Discord" / "Ooze_My Music"
  function oozeLoopbackLabel(node) {
    const n = root.nodeProp(node, "node.name")
    const raw = n.replace(/^playback\./i, "").replace(/^ooze_/i, "")
    const nice = raw.split(/[_-]+/).filter(s => s !== "")
      .map(s => s.charAt(0).toUpperCase() + s.slice(1)).join(" ")
    return "Ooze_" + (nice || raw)
  }

  // application.name → node.description → node.name (igual que el ejemplo)
  function streamApp(node) {
    if (root.isOozeLoopback(node)) return root.oozeLoopbackLabel(node)
    return root.nodeProp(node, "application.name")
        || root.nodeProp(node, "node.description")
        || (node ? node.description : "")
        || (node ? node.nickname : "")
        || (node ? node.name : "")
        || root.nodeProp(node, "node.name")
        || "?"
  }

  // "Firefox • título de la pestaña" si el stream informa media.name.

  function streamLabel(node) {
    const app = root.streamApp(node)
    if (root.isOozeLoopback(node)) return app
    const media = root.nodeProp(node, "media.name")
    return media !== "" ? app + " • " + media : app
  }

  // Un stream de reproducción es Audio|Sink|Stream (media.class
  // "Stream/Output/Audio"). `isStream`/`isSink`/`audio` salen del registro de
  // PipeWire y NO dependen de que el nodo esté bindeado. `properties`, en cambio,
  // queda vacío si el nodo no está bindeado (o se desbindea), así que NO se usa
  // para filtrar: antes eso dejaba filas fantasma "?" al 0%.
  function isPlaybackStream(n) {
    return !!n && n.isStream && n.isSink && !!n.audio
  }

  function scanStreams() {
    const out = []
    const nodes = Pipewire.nodes.values
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!root.isPlaybackStream(n)) continue
      out.push(n)
    }
    // Solo se reasigna si cambió el conjunto de streams (así ScriptModel no
    // recrea filas ni interrumpe un arrastre de slider).
    const key = out.map(n => n.id).join(",")
    if (key !== root.streamNodesKey) { root.streamNodesKey = key; root.streamNodes = out }
  }

  // Aparece/desaparece un nodo → re-escanear al toque
  Connections {
    target: Pipewire.nodes
    function onValuesChanged() { if (root.menuWatch) root.scanStreams() }
  }

  // Red de seguridad: node.properties / node.audio llegan un instante DESPUÉS
  // de que el nodo aparece (cuando el tracker lo bindea) y ese cambio no
  // avisa por señal. Solo corre con el panel abierto.
  Timer {
    interval: 1000
    running: root.menuWatch
    repeat: true
    triggeredOnStart: true
    onTriggered: root.scanStreams()
  }

  Timer {
    interval: 1500
    running: root.menuWatch
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshDevices()
  }

  onMenuWatchChanged: {
    if (root.menuWatch) { root.refreshDevices(); root.scanStreams() }
    else { root.streamNodesKey = ""; root.streamNodes = [] }
  }

  // ── Cambiar el dispositivo por defecto ──────────────────────────
  Process {
    id: setDefaultProc
    property string devId: ""
    command: ["wpctl", "set-default", devId]
    running: false
    onRunningChanged: { if (!running) afterDefaultTimer.restart() }
  }
  Timer {
    id: afterDefaultTimer
    interval: 250
    repeat: false
    onTriggered: { root.refreshDevices(); root.refreshVolumes() }
  }

  function setDefaultSink(id)   { root.setDefault(id) }
  function setDefaultSource(id) { root.setDefault(id) }
  function setDefault(id) {
    setDefaultProc.devId = String(id)
    setDefaultProc.running = false
    setDefaultProc.running = true
  }
}
