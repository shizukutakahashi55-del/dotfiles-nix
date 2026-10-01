import QtQuick

// ChartGrid — líneas guía horizontales para las gráficas (25 / 50 / 75 %).
// Sin ellas una gráfica de historial es un manchón flotando sobre un fondo
// vacío: con la cuadrícula se lee de un vistazo "a qué altura va".
//   dotted: false → líneas finas continuas (OozeSoft)
//   dotted: true  → punteado de 2 px, como el tramado de CoOzey
Item {
  id: root
  property color color: Theme.text
  property real alpha: 0.10
  property bool dotted: false
  property var fractions: [0.25, 0.5, 0.75]

  Canvas {
    id: cv
    anchors.fill: parent
    // Sin antialias: las líneas caen en píxel entero y se ven nítidas
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      if (width <= 0 || height <= 0) return
      ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.alpha)
      for (let i = 0; i < root.fractions.length; i++) {
        const y = Math.round(height * root.fractions[i])
        if (root.dotted) {
          for (let x = 0; x < width; x += 4) ctx.fillRect(x, y, 2, 2)
        } else {
          ctx.fillRect(0, y, width, 1)
        }
      }
    }
  }

  onColorChanged: cv.requestPaint()
  onAlphaChanged: cv.requestPaint()
  onDottedChanged: cv.requestPaint()
  onFractionsChanged: cv.requestPaint()
}
