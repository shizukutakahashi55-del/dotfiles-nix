// MprisWaves.qml — MPRIS

import QtQuick
import QtQuick.Shapes
import "../COMMON"

// ─────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────
Item {
  id: root
  clip: true

  rotation: root.flip ? 180 : 0


  property bool running: false

  property bool playing: false

  property real sf: 1
  property bool flip: false

  property bool reactive: true


  readonly property bool live: root.reactive && root.playing
    && AudioLevels.available && !AudioLevels.silent

  // ─── Geometría de las ondas ─────────────────────────────────


  function waveHumps(w, period) {
    if (period < 1 || w <= 0) return 0
    return Math.min(200, Math.ceil((w + period) / (period / 2)))
  }
  function waveEnd(w, period) { return root.waveHumps(w, period) * period / 2 }
  function waveLine(w, period, amp, y0) {
    const n = root.waveHumps(w, period)
    if (n === 0) return ""
    const half = period / 2
    let p = "M 0 " + y0.toFixed(2)
    for (let i = 0; i < n; i++) {
      const x0 = i * half
      const cy = y0 + (i % 2 === 0 ? -2 * amp : 2 * amp)
      p += " Q " + (x0 + half / 2).toFixed(2) + " " + cy.toFixed(2)
         + " " + (x0 + half).toFixed(2) + " " + y0.toFixed(2)
    }
    return p
  }

  // ─── Capas sinusoidales ─────────────────────────────────────
  Repeater {
    visible: !Theme.cozy
    model: [


      { period: 320, amp: 8, rise: 74, alpha: 0.08, stroke: 0.0,  dur: 16000, dir: -1, breath: 4200, zone: 0, gain: 1.2 },
      { period: 230, amp: 7, rise: 52, alpha: 0.10, stroke: 0.22, dur: 11000, dir:  1, breath: 3300, zone: 1, gain: 1.3 },
      { period: 180, amp: 5, rise: 32, alpha: 0.13, stroke: 0.30, dur:  8000, dir: -1, breath: 2700, zone: 2, gain: 1.6 }
    ]

    delegate: Item {
      id: wv
      required property var modelData

      readonly property real period: modelData.period * root.sf
      readonly property real amp: modelData.amp * root.sf
      readonly property real rise: modelData.rise * root.sf


      readonly property real punch: root.live ? AudioLevels.zones[modelData.zone] : 0
      readonly property real ampCap: amp * (0.65 + modelData.gain) * 1.1
      readonly property real y0: ampCap + 2


      property real level: root.playing ? 0.65 : 0.4
      Behavior on level { NumberAnimation { duration: Theme.animDuration(700); easing.type: Easing.InOutSine } }

      property real breath: 1.0
      SequentialAnimation on breath {
        running: (!Theme.cozy && root.running && root.playing) && Theme.uiAnimationsEnabled
        loops: Animation.Infinite
        NumberAnimation { to: 1.06; duration: Theme.animDuration(wv.modelData.breath); easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.94; duration: Theme.animDuration(wv.modelData.breath); easing.type: Easing.InOutSine }
      }
      readonly property real ampNow:
        Math.min(ampCap, amp * (level + modelData.gain * punch) * breath)

      readonly property string line: root.waveLine(width, period, ampNow, y0)
      readonly property color fillCol: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                               modelData.alpha * (1 + 0.6 * punch))
      readonly property color strokeCol: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                                 modelData.stroke * (1 + 0.5 * punch))


      width: root.width + period
      height: rise + y0
      y: root.height - height

      property real phase: 0
      x: modelData.dir > 0 ? -period * (1 - phase) : -period * phase
      NumberAnimation on phase {
        from: 0; to: 1
        duration: Theme.animDuration(wv.modelData.dur)
        loops: Animation.Infinite
        running: (!Theme.cozy && root.running) && Theme.uiAnimationsEnabled
        paused: !root.playing && (!Theme.cozy && root.running) && Theme.uiAnimationsEnabled
      }

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer


        ShapePath {
          fillColor: wv.fillCol
          strokeWidth: -1
          strokeColor: "transparent"
          PathSvg {
            path: wv.line === "" ? ""
              : wv.line
                + " L " + root.waveEnd(wv.width, wv.period).toFixed(2)
                + " " + wv.height.toFixed(2)
                + " L 0 " + wv.height.toFixed(2) + " Z"
          }
        }


        ShapePath {
          fillColor: "transparent"
          strokeColor: wv.strokeCol
          strokeWidth: wv.modelData.stroke > 0 ? 1.5 : -1
          capStyle: ShapePath.RoundCap
          PathSvg { path: wv.modelData.stroke > 0 ? wv.line : "" }
        }
      }
    }
  }

  // ─── Espectro (delante de todo) ─────────────────────────────


  SpectrumBars {
    id: spec
    width: root.width
    height: (16 + 54) * root.sf
    y: root.height - height
    active: root.reactive && root.playing && root.running
    hideWhenIdle: true
    minBarHeight: 3 * root.sf
    barSpacing: 4 * root.sf
    ledSpacing: 3
    activeOpacity: 0.22
    ledActiveOpacity: 0.28
    color: Theme.primary
  }

  // ─── CoOzey: colinas de píxeles ─────────────────────────────


  Item {
    id: cozyLayer
    anchors.fill: parent
    visible: Theme.cozy
    property int tick: 0
    readonly property int cw: Math.max(6, Math.round(8 * root.sf))
    readonly property int step: 4

    Timer {
      interval: 140; repeat: true
      running: Theme.cozy && root.running && root.playing
      onTriggered: cozyLayer.tick++
    }

    Repeater {
      model: [

        { base: 50, amp: 8, alpha: 0.10, k: 0.22, dir:  1, zone: 0, gain: 26 },
        { base: 34, amp: 7, alpha: 0.14, k: 0.31, dir: -1, zone: 1, gain: 22 },
        { base: 18, amp: 5, alpha: 0.20, k: 0.43, dir:  1, zone: 2, gain: 18 }
      ]
      delegate: Item {
        id: hill
        required property var modelData
        required property int index
        anchors.fill: parent
        readonly property real punch: root.live ? AudioLevels.zones[modelData.zone] : 0

        Repeater {
          model: Theme.cozy ? Math.ceil(root.width / cozyLayer.cw) + 1 : 0
          delegate: Item {
            id: col
            required property int index
            readonly property real raw: (hill.modelData.base
              + hill.modelData.amp * Math.sin(index * hill.modelData.k
                  + cozyLayer.tick * 0.35 * hill.modelData.dir + hill.index * 1.7)
              + hill.modelData.gain * hill.punch) * root.sf
            readonly property int h: Math.max(cozyLayer.step,
              Math.round(col.raw / cozyLayer.step) * cozyLayer.step)
            x: index * cozyLayer.cw
            width: cozyLayer.cw
            y: root.height - h
            height: h
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 1.6) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 0.5) }
              }
            }
            Rectangle {
              width: parent.width; height: 2
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hill.modelData.alpha * 2.6)
            }
          }
        }
      }
    }
  }
}
