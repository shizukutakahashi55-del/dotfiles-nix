pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Core/Toml.js" as Toml

Singleton {
  id: root

  readonly property string file: Quickshell.env("HOME") + "/.config/oozeshell/equalizer.toml"
  readonly property string script: decodeURIComponent(Qt.resolvedUrl("../../Tools/eq-chain.sh").toString().replace("file://", ""))

  readonly property var freqs: [60, 120, 250, 500, 1000, 2000, 4000, 8000]
  readonly property var freqLabels: ["60", "120", "250", "500", "1k", "2k", "4k", "8k"]
  readonly property var presets: [
    { id: "flat",  key: "eqPresetFlat",  gains: [0, 0, 0, 0, 0, 0, 0, 0] },
    { id: "bass",  key: "eqPresetBass",  gains: [6, 5, 3, 1, 0, 0, 0, 0] },
    { id: "vocal", key: "eqPresetVocal", gains: [-2, -2, -1, 2, 4, 4, 2, 0] },
    { id: "rock",  key: "eqPresetRock",  gains: [4, 3, 1, -1, -1, 2, 4, 4] },
    { id: "jazz",  key: "eqPresetJazz",  gains: [3, 2, 1, 2, -1, -1, 1, 3] }
  ]

  property bool enabled: false
  property string preset: "flat"
  property var gains: [0, 0, 0, 0, 0, 0, 0, 0]
  property real preamp: 0
  property real balance: 0
  property real bass: 0
  property real treble: 0
  property string bandwidth: "normal"
  property bool autoPreamp: true
  property bool loaded: false
  property bool busy: false
  property string error: ""
  property string targetDesc: ""

  property bool open: false
  property string screenName: ""

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  readonly property var bandwidths: [
    { id: "narrow", key: "eqBwNarrow", q: 2.2 },
    { id: "normal", key: "eqBwNormal", q: 1.4 },
    { id: "wide",   key: "eqBwWide",   q: 0.8 }
  ]
  readonly property real q: (root.bandwidths.find(b => b.id === root.bandwidth) ?? root.bandwidths[1]).q
  readonly property real autoCut: root.autoPreamp
    ? Math.max(0, Math.max.apply(null, root.gains), root.bass, root.treble)
    : 0

  function args() {
    return root.gains.map(g => Number(g).toFixed(2)).concat([
      Number(root.preamp - root.autoCut).toFixed(2),
      Number(root.balance).toFixed(2),
      Number(root.bass).toFixed(2),
      Number(root.treble).toFixed(2),
      Number(root.q).toFixed(2)
    ])
  }

  function matchPreset() {
    for (const p of root.presets) {
      if (p.gains.every((g, i) => Math.abs(g - root.gains[i]) < 0.01) && Math.abs(root.preamp) < 0.01) return p.id
    }
    return ""
  }

  function applyConfig(text) {
    let j = {}
    try { j = Toml.parseAny(text) } catch (e) { j = {} }
    if (Array.isArray(j.gains) && j.gains.length === 8)
      root.gains = j.gains.map(v => root.clamp(Number(v) || 0, -12, 12))
    root.preamp = root.clamp(Number(j.preamp) || 0, -12, 12)
    root.balance = root.clamp(Number(j.balance) || 0, -1, 1)
    root.bass = root.clamp(Number(j.bass) || 0, -12, 12)
    root.treble = root.clamp(Number(j.treble) || 0, -12, 12)
    root.bandwidth = root.bandwidths.some(b => b.id === j.bandwidth) ? j.bandwidth : "normal"
    root.autoPreamp = j.autoPreamp !== false
    root.preset = typeof j.preset === "string" ? j.preset : root.matchPreset()
    root.enabled = j.enabled === true
    root.loaded = true
    if (root.enabled) root.start()
    else statusProc.running = true
  }

  FileView {
    id: cfgView
    path: root.file
    onLoaded: root.applyConfig(cfgView.text())
    onLoadFailed: root.loaded = true
  }

  Process { id: saveProc }

  function save() {
    const data = Toml.stringify({
      enabled: root.enabled,
      preset: root.preset,
      gains: root.gains,
      preamp: root.preamp,
      balance: root.balance,
      bass: root.bass,
      treble: root.treble,
      bandwidth: root.bandwidth,
      autoPreamp: root.autoPreamp
    })
    saveProc.command = ["bash", "-c",
      "mkdir -p \"$(dirname \"$2\")\" && printf %s \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\"",
      "sh", data, root.file]
    saveProc.running = false
    saveProc.running = true
  }

  function parseResult(out) {
    const t = String(out ?? "").trim()
    if (t === "ok" || t === "on") { root.error = ""; return true }
    if (t.indexOf("missing:") === 0) root.error = t.slice(8)
    else root.error = t === "" ? "" : t
    return false
  }

  Process {
    id: startProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.busy = false
        if (!root.parseResult(text)) {
          root.enabled = false
          root.targetDesc = ""
          root.save()
        } else {
          targetProc.running = false
          targetProc.running = true
        }
      }
    }
  }

  Process {
    id: stopProc
    stdout: StdioCollector { onStreamFinished: { root.busy = false; root.targetDesc = "" } }
  }

  Process {
    id: applyProc
    stdout: StdioCollector {
      onStreamFinished: if (String(text).trim() === "off" && root.enabled && !root.busy) root.start()
    }
  }

  Process {
    id: statusProc
    command: ["bash", root.script, "status"]
    stdout: StdioCollector {
      onStreamFinished: if (String(text).trim() === "on") {
        root.enabled = true
        root.save()
        targetProc.running = false
        targetProc.running = true
      }
    }
  }

  Process {
    id: targetProc
    command: ["bash", root.script, "target"]
    stdout: StdioCollector { onStreamFinished: root.targetDesc = String(text).trim() }
  }

  function start() {
    if (root.busy) return
    root.busy = true
    startProc.command = ["bash", root.script, "start"].concat(root.args())
    startProc.running = false
    startProc.running = true
  }

  function stop() {
    root.busy = true
    stopProc.command = ["bash", root.script, "stop"]
    stopProc.running = false
    stopProc.running = true
  }

  function setEnabled(v) {
    if (v === root.enabled || root.busy) return
    root.enabled = v
    root.error = ""
    if (v) root.start()
    else root.stop()
    root.save()
  }

  function toggleEnabled() { root.setEnabled(!root.enabled) }

  Timer {
    id: applyTimer
    interval: 60
    onTriggered: {
      if (!root.enabled || root.busy) return
      applyProc.command = ["bash", root.script, "apply"].concat(root.args())
      applyProc.running = false
      applyProc.running = true
    }
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: root.save()
  }

  function changed() {
    applyTimer.restart()
    saveTimer.restart()
  }

  function setGain(i, v) {
    const g = root.gains.slice()
    g[i] = Math.round(root.clamp(v, -12, 12) * 2) / 2
    root.gains = g
    root.preset = root.matchPreset()
    root.changed()
  }

  function setPreset(id) {
    const p = root.presets.find(x => x.id === id)
    if (!p) return
    root.gains = p.gains.slice()
    root.preamp = 0
    root.preset = id
    root.changed()
  }

  function setPreamp(v) {
    root.preamp = Math.round(root.clamp(v, -12, 12) * 2) / 2
    root.preset = root.matchPreset()
    root.changed()
  }

  function setBalance(v) {
    root.balance = Math.round(root.clamp(v, -1, 1) * 20) / 20
    root.changed()
  }

  function setBass(v) {
    root.bass = Math.round(root.clamp(v, -12, 12) * 2) / 2
    root.changed()
  }

  function setTreble(v) {
    root.treble = Math.round(root.clamp(v, -12, 12) * 2) / 2
    root.changed()
  }

  function setBandwidth(id) {
    if (!root.bandwidths.some(b => b.id === id)) return
    root.bandwidth = id
    root.changed()
  }

  function setAutoPreamp(v) {
    root.autoPreamp = v
    root.changed()
  }

  function reset() {
    root.gains = [0, 0, 0, 0, 0, 0, 0, 0]
    root.preamp = 0
    root.balance = 0
    root.bass = 0
    root.treble = 0
    root.preset = "flat"
    root.changed()
  }

  function openWindow(screen) {
    root.screenName = screen || root.screenName
    root.open = true
  }
  function closeWindow() { root.open = false }
  function toggleWindow(screen) {
    if (root.open) root.closeWindow()
    else root.openWindow(screen)
  }
}
