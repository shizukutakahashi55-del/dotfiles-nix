// MdShape — COMMON

import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property string shape: "circle"
  property color color: Theme.primary
  property color strokeColor: "transparent"
  property real strokeWidth: 0
  property bool pixelize: true

  readonly property string shown:
    (Theme.cozy && root.pixelize && MdShapes.pixelNames.indexOf(root.shape) < 0) ? "pixelCircle" : root.shape
  readonly property var def: MdShapes.get(root.shown)
  readonly property real k: Math.max(0.001, Math.min(root.width / root.def.w, root.height / root.def.h))

  implicitWidth: 40
  implicitHeight: 40

  Shape {
    x: (root.width - root.def.w * root.k) / 2 - root.def.x * root.k
    y: (root.height - root.def.h * root.k) / 2 - root.def.y * root.k
    width: 380
    height: 380
    scale: root.k
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      strokeColor: root.strokeWidth > 0 ? root.strokeColor : "transparent"
      strokeWidth: root.strokeWidth > 0 ? root.strokeWidth / root.k : -1
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: root.def.p }
    }
  }
}
