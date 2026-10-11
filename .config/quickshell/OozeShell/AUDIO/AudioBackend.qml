// AudioBackend

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
  id: root

  // ─── Quién está mirando ────────────────────────────────────────


  property int watchers: 0
  readonly property bool menuWatch: watchers > 0
  function acquireWatch() { root.watchers = root.watchers + 1 }
  function releaseWatch() { root.watchers = Math.max(0, root.watchers - 1) }
  property bool dragging: false
  property bool micDragging: false

  // ─── Estado: salida (sink) por defecto ──────────────────────────
  property real volume: 0
  property bool muted: false

  // ─── Estado: entrada (source/mic) por defecto ───────────────────
  property real micVolume: 0
  property bool micMuted: false

  // ─── Nodos por defecto (event-driven, sin poll) ────────────────


  readonly property var sinkNode: Pipewire.defaultAudioSink
  readonly property var srcNode: Pipewire.defaultAudioSource
  readonly property bool pwLive: !!(root.sinkNode && root.sinkNode.audio)
  function syncSink() {
    const a = root.sinkNode ? root.sinkNode.audio : null
    if (!a) return
    if (!root.dragging) root.volume = Math.min(1, a.volume)
    root.muted = a.muted
  }
  function syncMic() {
    const a = root.srcNode ? root.srcNode.audio : null
    if (!a) return
    if (!root.micDragging) root.micVolume = Math.min(1, a.volume)
    root.micMuted = a.muted
  }
  onSinkNodeChanged: root.syncSink()
  onSrcNodeChanged: root.syncMic()
  Connections {
    target: root.sinkNode ? root.sinkNode.audio : null
    function onVolumeChanged() { root.syncSink() }
    function onMutedChanged() { root.syncSink() }
  }
  Connections {
    target: root.srcNode ? root.srcNode.audio : null
    function onVolumeChanged() { root.syncMic() }
    function onMutedChanged() { root.syncMic() }
  }

  // ─── Listas de dispositivos (solo mientras el panel está abierto)
  property var sinks: []
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

  // ═══════════════════════════════════════════════════════════════
  property bool osdVisible: false
  property string osdKind: "volume"
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


  function toggleMuteOsd() {
    root.toggleMute()
    root.muted = !root.muted
    root.showOsd("volume", root.volume, root.muted)
  }


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


  Timer {
    interval: 1500
    running: !root.pwLive
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshVolumes()
  }

  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════


  function applyStatus(lines) {
    let section = ""
    const sinksArr = []
    const sourcesArr = []


    const devRe = /^[\s│]*(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:\s*([0-9.]+)\s*(MUTED)?\]\s*$/

    const hdrRe = /(?:[├└]─|^)\s*(Devices|Sinks|Sources|Filters|Streams):\s*$/
    for (const raw of lines) {
      const h = raw.match(hdrRe)
      if (h) {
        section = h[1] === "Sinks" ? "sinks" : h[1] === "Sources" ? "sources" : ""
        continue
      }

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

  // ═══════════════════════════════════════════════════════════════


  property var streamNodes: []
  property string streamNodesKey: ""


  PwObjectTracker { objects: Pipewire.nodes.values }

  function nodeProp(node, key) {
    const p = node ? node.properties : null
    return (p && p[key] !== undefined) ? String(p[key]) : ""
  }

  // ── Salidas virtuales de OozeAudio (pw-loopback) ────────────────


  function isOozeLoopback(node) {
    const n = root.nodeProp(node, "node.name")
    return /^(playback\.)?ooze_/i.test(n)
  }


  function oozeLoopbackLabel(node) {
    const n = root.nodeProp(node, "node.name")
    const raw = n.replace(/^playback\./i, "").replace(/^ooze_/i, "")
    const nice = raw.split(/[_-]+/).filter(s => s !== "")
      .map(s => s.charAt(0).toUpperCase() + s.slice(1)).join(" ")
    return "Ooze_" + (nice || raw)
  }


  function cleanAppName(raw) {
    let n = String(raw || "")
    const alsa = n.match(/^PipeWire ALSA \[(.+)\]$/)
    if (alsa) n = alsa[1]
    n = n.replace(/^\.+/, "").replace(/[-_]wrapped$/i, "").replace(/-unwrapped$/i, "")
    return n
  }


  function streamApp(node) {
    if (root.isOozeLoopback(node)) return root.oozeLoopbackLabel(node)
    const raw = root.nodeProp(node, "application.name")
        || root.nodeProp(node, "node.description")
        || (node ? node.description : "")
        || (node ? node.nickname : "")
        || (node ? node.name : "")
        || root.nodeProp(node, "node.name")
        || "?"
    return root.cleanAppName(raw) || raw
  }


  function streamLabel(node) {
    const app = root.streamApp(node)
    if (root.isOozeLoopback(node)) return app
    const media = root.nodeProp(node, "media.name")
    return media !== "" ? app + " • " + media : app
  }


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


    const key = out.map(n => n.id).join(",")
    if (key !== root.streamNodesKey) { root.streamNodesKey = key; root.streamNodes = out }
  }


  Connections {
    target: Pipewire.nodes
    function onValuesChanged() { if (root.menuWatch) root.scanStreams() }
  }


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

  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════


  readonly property string oozeScript:
    Quickshell.env("HOME") + "/.config/quickshell/OozeShell/OozeAudio/backend/audio.sh"

  signal restored()

  // ── Restore ─────────────────────────────────────────────────────
  property bool restoreQueued: false

  function restoreOutputs() {
    if (restoreProc.running) { root.restoreQueued = true; return }
    restoreProc.running = true
  }

  Process {
    id: restoreProc
    command: ["bash", root.oozeScript, "restore"]
    running: false
    onRunningChanged: {
      if (running) return

      root.appliedStreams = ({})
      root.loadRules()
      root.restored()
      if (root.restoreQueued) { root.restoreQueued = false; root.restoreOutputs() }
    }
  }


  Timer {
    interval: 1500
    running: true
    repeat: false
    onTriggered: { root.restoreOutputs(); root.loadRules() }
  }


  Timer {
    id: reconcileTimer
    interval: 2000
    repeat: false
    onTriggered: root.restoreOutputs()
  }

  // ── Salidas disponibles (sinks de audio, incluidas las virtuales) ──

  property var outputTargets: []
  property string outputTargetsKey: ""

  function scanOutputTargets() {
    const out = []
    const nodes = Pipewire.nodes.values
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]

      if (!n || n.isStream || !n.isSink || !n.audio) continue
      const name = n.name || ""
      if (name === "") continue
      out.push({
        id: n.id,
        name: name,
        desc: n.description || n.nickname || name,
        virtual: /^ooze_/i.test(name)
      })
    }
    const key = out.map(o => o.name).join("|")
    if (key !== root.outputTargetsKey) {
      const first = root.outputTargetsKey === ""
      root.outputTargetsKey = key
      root.outputTargets = out

      if (!first) reconcileTimer.restart()
    }
  }

  // ── Reglas por app ──────────────────────────────────────────────
  property var appRules: ({})
  property var appliedStreams: ({})
  property var applyQueue: []


  function streamKey(node) {
    const raw = root.nodeProp(node, "application.process.binary")
             || root.nodeProp(node, "application.name")
             || root.nodeProp(node, "node.name")
    return raw.toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_.-]/g, "")
  }


  function ruleFor(node) {
    const k = root.streamKey(node)
    return k !== "" ? (root.appRules[k] || "") : ""
  }

  function loadRules() {
    rulesProc.running = false
    rulesProc.running = true
  }

  Process {
    id: rulesProc
    command: ["bash", root.oozeScript, "app-rules"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const rules = {}
        for (const line of text.split("\n")) {
          const f = line.split("\t")
          if (f.length >= 2 && f[0] !== "") rules[f[0]] = f[1]
        }
        root.appRules = rules
      }
    }
  }

  function pumpApply() {
    if (applyProc.running || root.applyQueue.length === 0) return
    const next = root.applyQueue.shift()
    applyProc.command = ["bash", root.oozeScript, "stream-move", String(next.id), next.sink]
    applyProc.running = true
  }

  Process {
    id: applyProc
    running: false
    onRunningChanged: { if (!running) root.pumpApply() }
  }


  function applyRules() {
    const rules = root.appRules
    if (Object.keys(rules).length === 0) return

    const nodes = Pipewire.nodes.values
    const prev = root.appliedStreams
    const next = {}
    const q = root.applyQueue.slice()

    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!root.isPlaybackStream(n) || root.isOozeLoopback(n)) continue
      if (prev[n.id]) { next[n.id] = true; continue }

      const key = root.streamKey(n)
      if (key === "") continue

      next[n.id] = true
      const sink = rules[key]
      if (sink) q.push({ id: n.id, sink: sink })
    }

    root.appliedStreams = next
    root.applyQueue = q
    root.pumpApply()
  }

  Timer {
    id: applyTimer
    interval: 300
    repeat: false
    onTriggered: root.applyRules()
  }


  Timer {
    interval: 2000
    repeat: true
    running: Object.keys(root.appRules).length > 0
    onTriggered: root.applyRules()
  }

  Connections {
    target: Pipewire.nodes
    function onValuesChanged() {
      root.scanOutputTargets()
      applyTimer.restart()
    }
  }

  Component.onCompleted: { root.scanOutputTargets(); root.syncSink(); root.syncMic() }


  function routeStream(node, sinkName) {
    if (!node) return
    const key = root.streamKey(node)
    if (key === "") return

    const rules = Object.assign({}, root.appRules)
    if (sinkName === "") {
      delete rules[key]
      routeProc.command = ["bash", root.oozeScript, "stream-unroute", String(node.id), key]
    } else {
      rules[key] = sinkName
      routeProc.command = ["bash", root.oozeScript, "stream-route", String(node.id), key, sinkName]
    }
    root.appRules = rules
    routeProc.running = false
    routeProc.running = true

    const applied = Object.assign({}, root.appliedStreams)
    applied[node.id] = true
    const q = root.applyQueue.slice()
    const nodes = Pipewire.nodes.values
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!root.isPlaybackStream(n) || root.isOozeLoopback(n) || n.id === node.id) continue
      if (root.streamKey(n) !== key) continue
      applied[n.id] = true
      q.push({ id: n.id, sink: sinkName === "" ? "default" : sinkName })
    }
    root.appliedStreams = applied
    root.applyQueue = q
    root.pumpApply()
  }

  Process { id: routeProc; running: false }


  function forgetRule(key) {
    const rules = Object.assign({}, root.appRules)
    delete rules[key]
    root.appRules = rules
    forgetProc.command = ["bash", root.oozeScript, "app-forget", key]
    forgetProc.running = false
    forgetProc.running = true
  }

  Process { id: forgetProc; running: false }

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
