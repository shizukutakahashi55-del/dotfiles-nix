// WidgetBorder

import QtQuick
import QtQuick.Shapes
import "../../COMMON"

Item {
  id: root

  property real radius: 14
  property real thickness: Theme.cozy ? Theme.inkWidth : 1.5

  readonly property real t: Math.max(1, root.thickness)
  readonly property real r: Math.max(0, Math.min(root.radius, Math.min(root.width, root.height) / 2))

  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.55, Math.min(0.78, c.hslLightness)), 0.95)
  }

  readonly property color c1: Theme.cozy ? Theme.ink : root.shifted(Theme.primary, 0.1)
  readonly property color c2: Theme.cozy ? Theme.ink : Theme.primary
  readonly property color c3: Theme.cozy ? Theme.ink : root.shifted(Theme.primary, -0.1)

  function loop(x, y, w, h, rr) {
    const k = Math.max(0, Math.min(rr, w / 2, h / 2))
    return "M" + (x + k) + "," + y
      + " H" + (x + w - k) + " A" + k + "," + k + " 0 0 1 " + (x + w) + "," + (y + k)
      + " V" + (y + h - k) + " A" + k + "," + k + " 0 0 1 " + (x + w - k) + "," + (y + h)
      + " H" + (x + k) + " A" + k + "," + k + " 0 0 1 " + x + "," + (y + h - k)
      + " V" + (y + k) + " A" + k + "," + k + " 0 0 1 " + (x + k) + "," + y + " Z"
  }

  readonly property string ringPath: root.width > 4 && root.height > 4
    ? root.loop(0, 0, root.width, root.height, root.r)
      + " " + root.loop(root.t, root.t, root.width - 2 * root.t, root.height - 2 * root.t, Math.max(0, root.r - root.t))
    : ""

  visible: root.width > 4 && root.height > 4

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill
      fillGradient: LinearGradient {
        x1: 0; y1: 0
        x2: root.width; y2: root.height
        GradientStop { position: 0.0; color: root.c1 }
        GradientStop { position: 0.5; color: root.c2 }
        GradientStop { position: 1.0; color: root.c3 }
      }
      PathSvg { path: root.ringPath }
    }
  }
}
