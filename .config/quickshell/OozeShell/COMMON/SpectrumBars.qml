// SpectrumBars — el visualizador de espectro ÚNICO del shell.
// Lo usan todos los reproductores (DashboardMpris y el popup de MPRIS/Mpris.qml vía MprisWaves): mismo dato (AudioLevels.bands), misma suavización, mismo dibujo. Antes cada uno tenía el suyo (24 barras con 24 Behavior, …

import QtQuick

Item {
  id: root


  property bool active: false

  property bool hideWhenIdle: false

  property int count: AudioLevels.bars
  property color color: Theme.primary


  property real attackMs: 45
  property real releaseMs: 120


  property real minBarHeight: 4
  property real barSpacing: 3
  property real activeOpacity: 0.30
  property real idleOpacity: 0.12


  property int ledCells: 8
  property real ledSpacing: 3
  property real ledActiveOpacity: 0.40
  property real ledIdleOpacity: 0.16

  readonly property bool led: Theme.cozy
  readonly property bool liveAudio: AudioLevels.available && !AudioLevels.silent


  property var shown: []
  property bool settled: true
  property var tgt: []
  property real phase: 0

  readonly property bool shouldShow: root.hideWhenIdle ? (root.active && root.liveAudio) : true
  opacity: root.shouldShow ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(450); easing.type: Easing.InOutSine } }

  // ─── Geometría ──────────────────────────────────────────────
  readonly property real barW: Math.max(1, (root.width - (root.count - 1) * root.barSpacing) / Math.max(1, root.count))
  readonly property int ledW: Math.max(3, Math.floor((root.width - (root.count - 1) * root.ledSpacing) / Math.max(1, root.count)))
  readonly property int ledX0: Math.max(0, Math.round((root.width - (root.count * root.ledW + (root.count - 1) * root.ledSpacing)) / 2))

  // ─── Objetivos ──────────────────────────────────────────────
  function retarget() {
    const n = root.count
    const t = new Array(n)
    if (!root.active) {
      for (let i = 0; i < n; i++) t[i] = 0.05
    } else if (root.liveAudio) {
      const b = AudioLevels.bands
      for (let i = 0; i < n; i++) t[i] = Math.max(0.06, b[i] || 0)
    } else {

      for (let i = 0; i < n; i++) t[i] = 0.20
    }
    root.tgt = t
    root.settled = false
  }

  onActiveChanged: root.retarget()
  onLiveAudioChanged: root.retarget()
  onCountChanged: { root.shown = []; root.retarget() }
  Component.onCompleted: root.retarget()

  Connections {
    target: AudioLevels
    function onBandsChanged() { if (root.active && root.liveAudio) root.retarget() }
  }

  // ─── Bucle de animación ─────────────────────────────────────
  function advance(dt) {
    const n = root.count
    const t = root.tgt
    if (t.length !== n) return

    const breathing = root.active && !root.liveAudio
    if (breathing) {

      root.phase = (root.phase + dt / 2.6) % 1
      for (let i = 0; i < n; i++)
        t[i] = 0.10 + 0.20 * (0.5 + 0.5 * Math.sin(root.phase * 6.2832 + i * 0.55))
    }

    const prev = root.shown
    const snap = !Theme.uiAnimationsEnabled
    const aUp = snap ? 1 : 1 - Math.exp(-dt * 1000 / root.attackMs)
    const aDn = snap ? 1 : 1 - Math.exp(-dt * 1000 / root.releaseMs)

    const out = new Array(n)
    let moving = false
    for (let i = 0; i < n; i++) {
      const cur = prev[i] === undefined ? 0 : prev[i]
      const diff = t[i] - cur
      if (Math.abs(diff) > 0.002) {
        out[i] = cur + diff * (diff > 0 ? aUp : aDn)
        moving = true
      } else {
        out[i] = t[i]
      }
    }
    root.shown = out
    root.settled = !moving && !breathing
  }

  FrameAnimation {
    running: root.visible && root.width > 0 && !root.settled
    onTriggered: root.advance(frameTime)
  }

  // ─── Piel suave: barras redondeadas ─────────────────────────
  Item {
    anchors.fill: parent
    visible: !root.led
    opacity: root.active ? root.activeOpacity : root.idleOpacity
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(300) } }

    Repeater {
      model: root.led ? 0 : root.count
      delegate: Rectangle {
        required property int index
        readonly property real v: root.shown[index] === undefined ? 0 : root.shown[index]
        x: Math.round(index * (root.barW + root.barSpacing))
        width: Math.max(1, Math.round(root.barW))
        height: Math.round(root.minBarHeight + v * Math.max(0, root.height - root.minBarHeight))
        y: root.height - height
        radius: width / 2
        color: root.color
      }
    }
  }

  // ─── CoOzey: columnas de LEDs ───────────────────────────────


  Item {
    anchors.fill: parent
    visible: root.led

    Repeater {
      model: root.led ? root.count : 0
      delegate: PixelLevels {
        required property int index
        x: root.ledX0 + index * (root.ledW + root.ledSpacing)
        width: root.ledW
        height: root.height
        cells: root.ledCells
        level: root.shown[index] === undefined ? 0 : root.shown[index]
        color: root.color
        litOpacity: root.active ? root.ledActiveOpacity : root.ledIdleOpacity
      }
    }
  }
}
