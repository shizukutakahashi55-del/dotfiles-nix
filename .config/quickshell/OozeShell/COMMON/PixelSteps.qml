import QtQuick

// PixelSteps — historial en columnas escalonadas (reemplaza a la línea suave
// del Sparkline): cada muestra es una columna cuya altura se redondea a
// "filas" de `cellH` px, con degradado y una tapa clara arriba. Las muestras
// nuevas entran por la derecha.
Item {
  id: root
  clip: true
  property var values: []
  property int maxSamples: 30
  property real maxValue: 100
  property color color: Theme.primary
  property int cellH: 4
  property int gap: 1

  readonly property real colW: (root.width - (root.maxSamples - 1) * root.gap) / Math.max(1, root.maxSamples)
  readonly property int rows: Math.max(1, Math.floor(root.height / root.cellH))

  Repeater {
    model: root.maxSamples
    Item {
      required property int index
      readonly property int off: root.maxSamples - root.values.length
      readonly property real v: index - off >= 0 ? root.values[index - off] : -1
      property int h: v < 0 ? 0 : Math.max(1, Math.ceil(Math.max(0, Math.min(root.maxValue, v)) / root.maxValue * root.rows)) * root.cellH
      x: Math.round(index * (root.colW + root.gap))
      width: Math.max(1, Math.round(root.colW))
      y: root.height - h
      height: h
      Behavior on h { NumberAnimation { duration: 180 } }
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.85) }
          GradientStop { position: 1.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.28) }
        }
      }
      Rectangle {   // tapa clara
        width: parent.width; height: Math.min(2, parent.height)
        color: Theme.mix(root.color, "#ffffff", 0.35)
      }
    }
  }
}
