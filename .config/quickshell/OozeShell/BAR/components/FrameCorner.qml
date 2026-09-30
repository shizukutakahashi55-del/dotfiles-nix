// FrameCorner — piecita de esquina del "marco" de pantalla.
//
// Fusiona en un solo componente reutilizable lo que antes eran DOS cosas
// separadas y sin cablear en ningún lado:
//   • el CornerPiece que vivía definido inline dentro de BAR/Bar.qml
//   • BAR/components/ConcaveCurves.qml (misma idea, nunca importada)
//
// Es un cuarto de círculo que "muerde" el ángulo recto de una esquina de
// pantalla: pintado del color de la barra, hace que el escritorio se vea
// con esa esquina redondeada. atRight/atBottom eligen cuál de las 4
// esquinas. El radio NO se fija acá: se lee de Theme.frameCornerRadius,
// que ya resuelve el estilo activo (Ajustes → Avanzado → Interfaz):
//   • "corners" → radio chico y fijo (Theme.screenCorner) = el look de
//     siempre, solo esquinas.
//   • "curved"  → radio más grande y suave (Theme.frameCurveRadius),
//     pensado para acompañar las 3 líneas de borde de BAR/Border.qml y
//     armar un marco continuo.
//
// ── armX / armY: el grosor de lo que hay pegado a cada lado ──────────
// Antes la pieza era SIEMPRE un cuadrado r×r, pensado solo para el estilo
// "corners" (sin bordes). Al sumarle BAR/Border.qml (bordes de grosor
// Theme.frameThickness, ahora hasta 150px) esto se rompía apenas el
// grosor del borde (t) era distinto del radio (r): la curva terminaba en
// una punta de ancho ~0 justo donde el borde recto empezaba con ancho t,
// y esa unión se veía como un escaloncito feo (el bug reportado).
//
// armX / armY dicen cuánto mide el borde recto con el que esta esquina
// se conecta en cada eje (0 si de ese lado no hay borde: lo cubre la
// barra, que ya es sólida y no necesita esquina). Con eso la pieza arma
// un cuarto de círculo que ARRANCA ancho (armX+r o armY+r, pegado a la
// barra) y se va achicando en curva hasta calzar EXACTO con el ancho del
// borde (armX o armY) al llegar a él — sin salto. Con armX=armY=0 esto
// colapsa exactamente en la pieza original (cuadrado r×r).
//
// Uso (ver BAR/Bar.qml):
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

        // Recorrido (sin espejar, esquina superior-izquierda): arranca en
        // el vértice de pantalla, bordea el brazo horizontal hasta el
        // ancho total, baja el alto del brazo vertical, muerde con el
        // cuarto de círculo hasta calzar con el ancho del borde vertical,
        // recorre el brazo vertical hacia adentro y cierra subiendo por
        // el borde de pantalla. Con armX=armY=0 varios puntos coinciden y
        // el path colapsa al cuadrado r×r de siempre.
        // atRight/atBottom espejan cada punto sobre w/h.
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
