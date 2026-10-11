// FrameCorner — piecita de esquina del "marco" de pantalla.

import QtQuick
import QtQuick.Shapes
import "../../COMMON"

Shape {
    id: root

    property bool atRight: false
    property bool atBottom: false


    property color fillColor: Theme.bg
    readonly property real r: Theme.frameCornerRadius


    property real armX: 0
    property real armY: 0


    readonly property real w: root.r + root.armX
    readonly property real h: root.r + root.armY

    width: root.w
    height: root.h
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeWidth: -1
        strokeColor: "transparent"

        startX: root.atRight ? root.w : 0
        startY: root.atBottom ? root.h : 0
        PathLine {
            x: root.atRight ? 0 : root.w
            y: root.atBottom ? root.h : 0
        }
        PathLine {
            x: root.atRight ? 0 : root.w
            y: root.atBottom ? (root.h - root.armY) : root.armY
        }

        PathArc {
            x: root.atRight ? (root.w - root.armX) : root.armX
            y: root.atBottom ? 0 : root.h
            radiusX: root.r; radiusY: root.r
            direction: root.atRight === root.atBottom
                ? PathArc.Counterclockwise : PathArc.Clockwise
        }
        PathLine {
            x: root.atRight ? root.w : 0
            y: root.atBottom ? 0 : root.h
        }
    }
}
