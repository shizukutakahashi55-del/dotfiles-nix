import QtQuick

// PixelBar — barra de progreso por bloques (estilo barra de vida/experiencia).
// Marco de tinta, celdas con degradado de `colorA` → `colorB`, y cada celda
// encendida lleva un brillo de 2 px arriba. La interacción (clic/arrastre)
// la pone quien la usa con un MouseArea encima.
Item {
  id: root
  property real ratio: 0
  property int cell: 6
  property int gap: 2
  property color colorA: Theme.mix(Theme.primary, Theme.bg, 0.40)
  property color colorB: Theme.primary
  property color track: Theme.tint(0.10)
  property color ink: Theme.ink
  implicitHeight: 14

  readonly property int inner: Math.max(0, root.width - 4)
  readonly property int count: Math.max(1, Math.floor((root.inner + root.gap) / (root.cell + root.gap)))
  readonly property int lit: Math.round(Math.max(0, Math.min(1, root.ratio)) * root.count)
  readonly property int x0: Math.round((root.width - (root.count * (root.cell + root.gap) - root.gap)) / 2)

  NotchRect { anchors.fill: parent; topColor: root.ink; notch: 2 }
  NotchRect {
    x: 2; y: 2; width: Math.max(0, root.width - 4); height: Math.max(0, root.height - 4)
    topColor: Qt.darker(Theme.bg, 1.15); notch: 2
  }

  Repeater {
    model: root.count
    Rectangle {
      required property int index
      readonly property bool on: index < root.lit
      x: root.x0 + index * (root.cell + root.gap)
      y: 4
      width: root.cell
      height: Math.max(2, root.height - 8)
      color: on ? Theme.mix(root.colorA, root.colorB, root.count > 1 ? index / (root.count - 1) : 1)
                : root.track
      Behavior on color { ColorAnimation { duration: 120 } }
      Rectangle {
        visible: parent.on
        x: 0; y: 0; width: parent.width; height: 2
        color: Qt.rgba(1, 1, 1, 0.28)
      }
    }
  }
}
