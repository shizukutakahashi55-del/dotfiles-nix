// FrameCorner — piecita de esquina del "marco" de pantalla.
//   FrameCorner { atRight: true; atBottom: false; armX: Theme.frameThickness }
import QtQuick
import QtQuick.Shapes
import "../../COMMON"

Shape {
    id: root

    property bool atRight: false
    property bool atBottom: false
    // Color de relleno: por defecto el de la barra, para que la pieza se
    // vea como una sola superficie con ella. Reemplazable si hiciera falta.
    property color fillColor: Theme.bg
    readonly property real r: Theme.frameCornerRadius

    // Grosor del borde recto contiguo en cada eje (0 = ese lado lo cubre
    // la barra, sin borde: la pieza queda como el cuarto de círculo simple
    // de siempre).
    property real armX: 0
    property real armY: 0

    // Tamaño total del recuadro: el brazo recto + el radio de la curva.
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
        // Superior-izq e inferior-der giran antihorario; las otras dos, horario.
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
