// LockSpectrum

import QtQuick
import "../../COMMON"

Item {
  id: root

  property real unit: 1
  property bool wanted: false
  property bool playing: false

  // ── Estado ──
  readonly property int n: AudioLevels.bars
  readonly property bool live: root.wanted && root.playing && AudioLevels.available && !AudioLevels.silent
  property var levels: []
  property bool settled: true

  implicitHeight: Math.round(26 * root.unit)

  FrameAnimation {
    running: root.wanted && (root.live || !root.settled)
    onTriggered: root.step(frameTime * 1000)
  }

  function step(dtMs) {
    const n = root.n
    const src = root.live ? AudioLevels.bands : []
    const ka = 1 - Math.exp(-dtMs / 45)
    const kr = 1 - Math.exp(-dtMs / 130)
    const prev = root.levels
    const out = new Array(n)
    let moving = false
    for (let i = 0; i < n; i++) {
      const p = i < prev.length ? prev[i] : 0
      const t = i < src.length ? src[i] : 0
      let v = p + (t - p) * (t > p ? ka : kr)
      if (Math.abs(t - v) < 0.003) v = t
      if (v !== t) moving = true
      out[i] = v
    }
    root.levels = out
    root.settled = !moving && !root.live
  }
  function val(i) { const v = root.levels[i]; return v === undefined ? 0 : v }

  // ── Paleta ──
  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
  }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  readonly property color toneA: Theme.primary
  readonly property color toneB: root.shifted(Theme.primary, -0.12)

  // ── Barras ──
  Repeater {
    model: root.wanted ? root.n : 0

    delegate: Rectangle {
      required property int index
      readonly property real slot: root.width / root.n
      readonly property real v: root.val(index)
      readonly property real gap: Math.max(2, slot * 0.3)
      x: index * slot + gap / 2
      width: Math.max(2, slot - gap)
      height: Math.max(3, Math.round(v * root.height))
      y: root.height - height
      radius: Theme.cozy ? 0 : Math.min(width / 2, 3)
      color: root.mix(root.toneA, root.toneB, root.n > 1 ? index / (root.n - 1) : 0)
      opacity: 0.55 + 0.45 * v
    }
  }
}
