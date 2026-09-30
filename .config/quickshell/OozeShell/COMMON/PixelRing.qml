import QtQuick

// PixelRing — medidor circular "de cuentas": en vez de un arco liso, un anillo
// de cuadritos que se van encendiendo en sentido horario desde las 12.
Item {
  id: root
  property real value: 0            // 0..100
  property int segments: 20
  property int cell: 6
  property color color: Theme.primary
  property color track: Theme.tint(0.12)
  property color ink: Theme.ink
  readonly property real r: (Math.min(root.width, root.height) - root.cell) / 2

  Repeater {
    model: root.segments
    Item {
      required property int index
      readonly property real a: (-90 + index * 360 / root.segments) * Math.PI / 180
      readonly property bool on: (index + 0.5) * 100 / root.segments <= root.value
      x: Math.round(root.width / 2 + root.r * Math.cos(a) - root.cell / 2)
      y: Math.round(root.height / 2 + root.r * Math.sin(a) - root.cell / 2)
      width: root.cell; height: root.cell
      // contorno de tinta + cuenta
      Rectangle { anchors.fill: parent; anchors.margins: -1; color: root.ink; opacity: parent.on ? 0.9 : 0.35 }
      Rectangle {
        anchors.fill: parent
        color: parent.on ? root.color : root.track
        Behavior on color { ColorAnimation { duration: Theme.animDuration(160) } }
        Rectangle {
          visible: parent.parent.on
          width: parent.width; height: 2
          color: Qt.rgba(1, 1, 1, 0.30)
        }
      }
    }
  }
}
