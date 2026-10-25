// MdWavy — COMMON

import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property real value: 0
  property bool playing: false
  property bool reactive: false
  property real amplitude: 3
  property real wavelength: 20
  property real thickness: 4
  property real speed: 34
  property bool handle: false
  property color tone: Theme.primary
  property color trackColor: Theme.withAlpha(Theme.text, 0.16)

  readonly property real ratio: Math.max(0, Math.min(1, root.value))
  readonly property real progressX: Math.round(root.width * root.ratio)
  readonly property bool live: root.reactive && root.playing && AudioLevels.available && !AudioLevels.silent
  readonly property real boost: root.live ? Math.min(1, AudioLevels.level * 1.6) : 0

  property real baseAmp: root.playing ? root.amplitude : 0
  Behavior on baseAmp { NumberAnimation { duration: Theme.animDuration(520); easing.type: Easing.InOutCubic } }

  readonly property real ampNow: root.baseAmp * (1 + 0.7 * root.boost)
  readonly property real mid: root.height / 2
  readonly property real gapPx: root.handle ? 6 : 4
  readonly property bool animating: root.playing && Theme.uiAnimationsEnabled && root.visible && root.width > 4

  property real phase: 0
  NumberAnimation on phase {
    from: 0
    to: 1
    loops: Animation.Infinite
    duration: Math.max(200, Math.round(root.wavelength / root.speed * 1000))
    running: root.animating
  }

  readonly property string wid: "wavy:" + Math.random().toString(36).slice(2)
  readonly property bool wantsAudio: root.reactive && root.playing && root.visible
  onWantsAudioChanged: AudioLevels.setWanted(root.wid, root.wantsAudio)
  Component.onDestruction: AudioLevels.setWanted(root.wid, false)

  function curve(w, period, amp, y0) {
    const half = period / 2
    const n = Math.min(240, Math.ceil(w / half) + 2)
    let p = "M 0 " + y0.toFixed(2)
    for (let i = 0; i < n; i++) {
      const x0 = i * half
      const cy = y0 + (i % 2 === 0 ? -2 * amp : 2 * amp)
      p += " Q " + (x0 + half / 2).toFixed(2) + " " + cy.toFixed(2)
         + " " + (x0 + half).toFixed(2) + " " + y0.toFixed(2)
    }
    return p
  }

  implicitHeight: Math.ceil(root.amplitude * 2 + root.thickness + 4)
  implicitWidth: 120

  Rectangle {
    id: track
    readonly property real startX: Math.min(root.width, root.progressX + root.gapPx + (root.handle ? 2 : 0))
    x: track.startX
    width: Math.max(0, root.width - track.startX)
    height: root.thickness
    y: root.mid - height / 2
    radius: height / 2
    color: root.trackColor
    visible: width > 0.5
  }

  Item {
    id: clipBox
    width: Math.max(0, root.progressX - (root.handle ? 2 : 0))
    height: root.height
    clip: true
    visible: width > 0.5

    Item {
      id: scroller
      x: -root.wavelength + root.phase * root.wavelength
      width: root.width + root.wavelength * 2
      height: root.height

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          fillColor: "transparent"
          strokeColor: root.tone
          strokeWidth: root.thickness
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin

          PathSvg { path: root.curve(scroller.width, root.wavelength, root.ampNow, root.mid) }
        }
      }
    }
  }

  Rectangle {
    visible: root.handle
    width: 4
    height: Math.max(root.thickness * 3.4, 14)
    radius: 2
    x: Math.max(0, Math.min(root.width - width, root.progressX - width / 2))
    y: root.mid - height / 2
    color: root.tone
  }
}
