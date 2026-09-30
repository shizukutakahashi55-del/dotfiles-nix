import QtQuick

// CozyButton — botón "de juego": cara con degradado, contorno de tinta con
// esquinas escalonadas y sombra dura. Al pulsar se hunde (la cara baja hasta
// la sombra). El contenido va dentro (se centra con anchors.centerIn: parent).
Item {
  id: root
  property color face: Theme.surface
  property color faceHover: Theme.surfaceHigh
  property int notch: 4
  property int depth: 3               // alto de la sombra dura
  property bool active: false          // "encendido" (perfil elegido, etc.)
  property bool hovered: ma.containsMouse
  property bool pressed: ma.pressed
  property alias cursorShape: ma.cursorShape
  signal clicked()
  default property alias content: face_.data

  // la sombra ocupa `depth` px abajo: la cara mide height - depth
  readonly property int sink: root.pressed ? root.depth : 0

  CozyBox {
    id: box
    x: 0
    y: root.sink
    width: root.width
    height: root.height - root.depth
    notch: root.notch
    shadow: !root.pressed
    shadowOffset: root.depth
    fillTop: Theme.mix(root.hovered ? root.faceHover : root.face, "#ffffff", root.active ? 0.18 : 0.10)
    fillBottom: root.hovered ? root.faceHover : root.face
    Item { id: face_; anchors.fill: parent }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
