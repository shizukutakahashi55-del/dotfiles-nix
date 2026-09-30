import QtQuick

// PixelLevels — una columna de "LEDs" (celdas apiladas) cuyo nivel (0..1) sube
// y baja: es la barra del ecualizador en versión pixel. La celda de más
// arriba encendida lleva un tono más claro.
Item {
  id: root
  property real level: 0
  property int cells: 8
  property int gap: 2
  property color color: Theme.primary
  property color off: Theme.tint(0.06)
  property real litOpacity: 1

  readonly property real cellH: (root.height - (root.cells - 1) * root.gap) / Math.max(1, root.cells)
  readonly property int lit: Math.round(Math.max(0, Math.min(1, root.level)) * root.cells)

  Repeater {
    model: root.cells
    Rectangle {
      required property int index
      readonly property bool on: index < root.lit
      readonly property bool cap: on && index === root.lit - 1
      x: 0
      width: root.width
      height: Math.max(1, Math.round(root.cellH))
      y: Math.round(root.height - (index + 1) * root.cellH - index * root.gap)
      color: cap ? Theme.mix(root.color, "#ffffff", 0.35) : (on ? root.color : root.off)
      opacity: on ? root.litOpacity : 1
      Behavior on color { ColorAnimation { duration: 90 } }
    }
  }
}
