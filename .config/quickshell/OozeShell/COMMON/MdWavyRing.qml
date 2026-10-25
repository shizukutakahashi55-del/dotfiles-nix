// MdWavyRing — COMMON

import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property real value: 0
  property bool running: false
  property real thickness: 8
  property real amplitude: 2.6
  property real waveLength: 24
  property color tone: Theme.primary
  property color trackColor: Theme.withAlpha(Theme.primary, 0.18)

  readonly property real ratio: Math.max(0, Math.min(1, root.value))
  readonly property real cx: root.width / 2
  readonly property real cy: root.height / 2
  readonly property real radius: Math.max(1, Math.min(root.width, root.height) / 2 - root.thickness / 2 - root.amplitude - 1)
  readonly property int waves: Math.max(5, Math.round(2 * Math.PI * root.radius / root.waveLength))

  property real baseAmp: root.running ? root.amplitude : 0
  Behavior on baseAmp { NumberAnimation { duration: Theme.animDuration(520); easing.type: Easing.InOutCubic } }

  property real phase: 0
  Timer {
    interval: 40
    repeat: true
    running: root.running && Theme.uiAnimationsEnabled && root.visible && root.ratio > 0.004
    onTriggered: root.phase = (root.phase + 0.16) % (Math.PI * 2)
  }

  function arcPath(ratio, amp, phase) {
    if (ratio <= 0.004) return ""
    const sweep = Math.PI * 2 * Math.min(ratio, 0.9995)
    const steps = Math.max(8, Math.ceil(sweep / (Math.PI * 2) * 150))
    const parts = []
    for (let i = 0; i <= steps; i++) {
      const t = i / steps
      const a = -Math.PI / 2 + sweep * t
      const taper = Math.min(1, Math.min(t, 1 - t) * 12 + (ratio > 0.99 ? 1 : 0.15))
      const r = root.radius + amp * taper * Math.sin(root.waves * (a + Math.PI / 2) - phase)
      parts.push((i === 0 ? "M " : "L ") + (root.cx + r * Math.cos(a)).toFixed(2) + " " + (root.cy + r * Math.sin(a)).toFixed(2))
    }
    return parts.join(" ")
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.trackColor
      strokeWidth: root.thickness
      fillColor: "transparent"

      PathAngleArc {
        centerX: root.cx
        centerY: root.cy
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: 359.9
      }
    }

    ShapePath {
      strokeColor: root.ratio > 0.004 ? root.tone : "transparent"
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: root.arcPath(root.ratio, root.baseAmp, root.phase) }
    }
  }
}
