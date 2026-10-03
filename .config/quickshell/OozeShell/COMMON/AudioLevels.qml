// AudioLevels — espectro del audio que está sonando, compartido.
//
// Corre `cava` (con su propio config, distinto al de la barra) SOLO mientras
// alguien lo pida, y publica los datos ya masticados para dibujar cosas:
//
//   AudioLevels.bands   → [0..1 × 24]  espectro, graves primero
//   AudioLevels.zones   → [bass, mid, treble]  (0..1, con ataque rápido y
//                         caída lenta, así "pegan" con el ritmo sin temblar)
//   AudioLevels.bass / .mid / .treble   → lo mismo, una por una
//   AudioLevels.level   → energía media de todo el espectro (0..1)
//   AudioLevels.silent  → ~1.5 s seguidos sin sonido
//   AudioLevels.available → ya llegó al menos un frame (cava está vivo)
//
// Cómo pedirlo (idempotente, cada cliente con su nombre; si nadie lo pide,
// cava se apaga y cuesta 0% de CPU):
//
//   AudioLevels.setWanted("mpris", true)     // empezar
//   AudioLevels.setWanted("mpris", false)    // dejar de necesitarlo
//
// Si `cava` no está instalado, `available` se queda en false y quien lo use
// debe seguir funcionando sin datos (las ondas de Mpris caen a "solo respiro").
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
  property var bands: []
  property var zones: [0, 0, 0]
  readonly property real bass: root.zones[0]
  readonly property real mid: root.zones[1]
  readonly property real treble: root.zones[2]
  property real level: 0
  property int silentFrames: 0
  readonly property bool silent: root.silentFrames > 90
  property bool available: false

  readonly property string configPath: "/tmp/oozeshell-cava-levels.conf"

  // Ataque rápido / caída lenta
  function env(prev, v) {
    return v > prev ? prev + (v - prev) * 0.65 : prev + (v - prev) * 0.14
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

    const iB = Math.max(1, Math.ceil(n / 6))     // graves: primer sexto
    const iM = Math.max(iB + 1, Math.round(n * 0.55))
    // Los agudos y medios llegan más flojos que los graves: se compensan
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

    // Solo corre si hay algún cliente
    running: root.wanted

    command: ["bash", "-c",
      "cat > '" + root.configPath + "' <<'CAVA_EOF'\n" +
      "[general]\n" +
      "framerate = 60\n" +
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
