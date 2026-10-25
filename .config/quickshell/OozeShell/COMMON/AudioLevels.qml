// AudioLevels — espectro del audio que está sonando, compartido.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // ─── Quién lo necesita ─────────────────────────────────────────
  property var wanters: ({})
  readonly property bool wanted: Object.keys(root.wanters).length > 0

  function setWanted(who, on) {
    if ((root.wanters[who] === true) === on) return
    const n = Object.assign({}, root.wanters)
    if (on) n[who] = true
    else delete n[who]
    root.wanters = n
  }

  // ─── Datos ─────────────────────────────────────────────────────
  readonly property int bars: 24


  readonly property int fps: 30
  property var bands: []
  property var zones: [0, 0, 0]
  readonly property real bass: root.zones[0]
  readonly property real mid: root.zones[1]
  readonly property real treble: root.zones[2]
  property real level: 0
  property int silentFrames: 0
  readonly property bool silent: root.silentFrames > root.fps * 1.5
  property bool available: false

  readonly property string configPath: "/tmp/oozeshell-cava-levels.conf"


  readonly property real envUp: 1 - Math.pow(1 - 0.65, 60 / root.fps)
  readonly property real envDown: 1 - Math.pow(1 - 0.14, 60 / root.fps)
  function env(prev, v) {
    return prev + (v - prev) * (v > prev ? root.envUp : root.envDown)
  }
  function clamp01(v) { return Math.max(0, Math.min(1, v)) }
  function avg(a, from, to) {
    if (to <= from) return 0
    let s = 0
    for (let i = from; i < to; i++) s += a[i]
    return s / (to - from)
  }

  function frame(line) {
    const parts = line.split(";")
    const out = []
    for (let i = 0; i < parts.length; i++) {
      if (parts[i] === "") continue
      out.push(root.clamp01((parseInt(parts[i]) || 0) / 100))
    }
    const n = out.length
    if (n === 0) return

    const iB = Math.max(1, Math.ceil(n / 6))
    const iM = Math.max(iB + 1, Math.round(n * 0.55))

    const b = root.clamp01(root.avg(out, 0, iB))
    const m = root.clamp01(root.avg(out, iB, iM) * 1.25)
    const t = root.clamp01(root.avg(out, iM, n) * 1.9)
    const z = root.zones

    root.bands = out
    root.zones = [root.env(z[0], b), root.env(z[1], m), root.env(z[2], t)]
    root.level = root.avg(out, 0, n)
    root.silentFrames = root.level < 0.015 ? Math.min(root.silentFrames + 1, 1000) : 0
    root.available = true
  }

  function reset() {
    root.bands = []
    root.zones = [0, 0, 0]
    root.level = 0
    root.silentFrames = 0
    root.available = false
  }

  Process {
    id: cava


    running: root.wanted

    command: ["bash", "-c",
      "cat > '" + root.configPath + "' <<'CAVA_EOF'\n" +
      "[general]\n" +
      "framerate = " + root.fps + "\n" +
      "autosens = 1\n" +
      "bars = " + root.bars + "\n" +
      "lower_cutoff_freq = 40\n" +
      "higher_cutoff_freq = 12000\n" +
      "[input]\n" +
      "method = pulse\n" +
      "source = auto\n" +
      "[output]\n" +
      "method = raw\n" +
      "raw_target = /dev/stdout\n" +
      "data_format = ascii\n" +
      "ascii_max_range = 100\n" +
      "bar_delimiter = 59\n" +
      "frame_delimiter = 10\n" +
      "channels = mono\n" +
      "[smoothing]\n" +
      "noise_reduction = 70\n" +
      "CAVA_EOF\n" +
      "exec cava -p '" + root.configPath + "'"
    ]

    stdout: SplitParser { onRead: line => root.frame(line) }
    stderr: SplitParser { onRead: line => console.log("[audiolevels]", line) }

    onRunningChanged: { if (!running) root.reset() }
  }
}
