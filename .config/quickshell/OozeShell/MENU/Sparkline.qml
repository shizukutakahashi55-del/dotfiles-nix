// Sparkline — mini gráfico de línea + área, alineado a la derecha
// (las muestras nuevas entran por ese lado). Valores 0..maxValue.
//
// Por defecto se ve como siempre (Menú). El Dashboard enciende las mejoras de
// legibilidad con estas propiedades opcionales:
//   fitData       la línea ocupa TODO el ancho aunque haya pocas muestras
//                 (antes, recién abierto, era un trazo diminuto a la derecha)
//   gradientArea  el área se desvanece hacia abajo en vez de ser plana
//   glow          halo suave bajo la línea
//   marker        punto con halo en la muestra más reciente
import QtQuick
import QtQuick.Shapes

Item {
  id: root
  clip: true

  property var values: []
  property int maxSamples: 30
  property real maxValue: 100
  property color lineColor: "#4a90d9"
  // Opcionales (por defecto, el aspecto de siempre; el Dashboard los sube)
  property real areaAlpha: 0.18
  property real lineWidth: 1.6
  property bool fitData: false
  property bool gradientArea: false
  property bool glow: false
  property bool marker: false

  readonly property var vals: root.values.length > root.maxSamples
                              ? root.values.slice(-root.maxSamples) : root.values
  readonly property int slots: root.fitData
                               ? Math.max(2, Math.min(root.vals.length, root.maxSamples))
                               : root.maxSamples
  // Espacio a la derecha para que el punto marcador no se recorte
  readonly property real rightPad: root.marker ? 5 : 0
  readonly property real plotW: Math.max(1, root.width - root.rightPad)
  readonly property real stepX: root.slots > 1 ? root.plotW / (root.slots - 1) : root.plotW

  function yFor(v) {
    const c = Math.max(0, Math.min(root.maxValue, v))
    return 3 + (root.height - 6) * (1 - c / root.maxValue)
  }

  readonly property string linePath: {
    const n = root.vals.length
    if (n < 2 || root.width <= 0 || root.height <= 0) return ""
    let p = ""
    for (let i = 0; i < n; i++) {
      const x = root.plotW - (n - 1 - i) * root.stepX
      p += (i === 0 ? "M " : " L ") + x.toFixed(1) + " " + root.yFor(root.vals[i]).toFixed(1)
    }
    return p
  }

  readonly property string areaPath: {
    if (root.linePath === "") return ""
    const n = root.vals.length
    const x0 = root.plotW - (n - 1) * root.stepX
    return root.linePath
      + " L " + root.plotW.toFixed(1) + " " + root.height.toFixed(1)
      + " L " + x0.toFixed(1) + " " + root.height.toFixed(1) + " Z"
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      strokeColor: "transparent"
      fillColor: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, root.areaAlpha)
      fillGradient: LinearGradient {
        x1: 0; y1: 0; x2: 0; y2: root.height
        GradientStop { position: 0.0; color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b,
                                                     root.gradientArea ? Math.min(0.75, root.areaAlpha * 1.9) : root.areaAlpha) }
        GradientStop { position: 1.0; color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b,
                                                     root.gradientArea ? 0.03 : root.areaAlpha) }
      }
      PathSvg { path: root.areaPath }
    }

    // Halo bajo la línea
    ShapePath {
      strokeColor: root.glow ? Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.18) : "transparent"
      strokeWidth: root.lineWidth * 3.2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.glow ? root.linePath : "" }
    }

    ShapePath {
      strokeColor: root.lineColor
      strokeWidth: root.lineWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.linePath }
    }
  }

  // Punto de la muestra más reciente
  Item {
    visible: root.marker && root.vals.length >= 2
    readonly property real ly: root.vals.length > 0 ? root.yFor(root.vals[root.vals.length - 1]) : 0
    x: root.plotW - 4
    y: ly - 4
    width: 8; height: 8
    Behavior on y { NumberAnimation { duration: Theme.animDuration(250); easing.type: Easing.OutCubic } }
    Rectangle {
      anchors.centerIn: parent
      width: 12; height: 12; radius: 6
      color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.22)
    }
    Rectangle {
      anchors.centerIn: parent
      width: 7; height: 7; radius: 3.5
      color: root.lineColor
    }
  }
}
