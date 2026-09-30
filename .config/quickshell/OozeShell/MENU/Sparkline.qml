// Sparkline — mini gráfico de línea + área, alineado a la derecha
// (las muestras nuevas entran por ese lado). Valores 0..maxValue.
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

  readonly property real stepX: maxSamples > 1 ? width / (maxSamples - 1) : width

  function yFor(v) {
    const c = Math.max(0, Math.min(root.maxValue, v))
    return 1 + (root.height - 3) * (1 - c / root.maxValue)
  }

  readonly property string linePath: {
    const n = root.values.length
    if (n < 2 || root.width <= 0 || root.height <= 0) return ""
    let p = ""
    for (let i = 0; i < n; i++) {
      const x = root.width - (n - 1 - i) * root.stepX
      p += (i === 0 ? "M " : " L ") + x.toFixed(1) + " " + root.yFor(root.values[i]).toFixed(1)
    }
    return p
  }

  readonly property string areaPath: {
    if (root.linePath === "") return ""
    const n = root.values.length
    const x0 = root.width - (n - 1) * root.stepX
    return root.linePath
      + " L " + root.width.toFixed(1) + " " + root.height.toFixed(1)
      + " L " + x0.toFixed(1) + " " + root.height.toFixed(1) + " Z"
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      strokeColor: "transparent"
      fillColor: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, root.areaAlpha)
      PathSvg { path: root.areaPath }
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
}
