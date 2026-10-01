import QtQuick

// SkinRect — reemplazo directo de `Rectangle` para tarjetas, botones y filas.
//   OozeSoft: un Rectangle normal (radius + color + border), idéntico al de siempre.
//   CoOzey:   caja PIXEL — contorno de tinta con esquinas escalonadas, relleno
//             plano con filo de luz arriba y (si `raised`) sombra dura debajo.
// Si `color` es transparente (filas que solo se iluminan al pasar el mouse) en
// CoOzey no se dibuja nada hasta que tenga color, igual que el original.
// `inkColor` cambia el contorno (p. ej. el botón elegido del PowerMenu).
Item {
  id: root
  property color color: Theme.surface
  property real radius: Theme.cardRadius
  property alias border: soft.border          // border.width / border.color (solo OozeSoft)
  property bool raised: false                 // sombra dura (deja `depth` px libres debajo)
  property int depth: 3
  property int notch: 4
  property color inkColor: Theme.ink
  default property alias content: body.data

  readonly property bool solidOn: root.color.a > 0.02

  // ── OozeSoft ──
  Rectangle {
    id: soft
    anchors.fill: parent
    visible: !Theme.cozy
    radius: root.radius
    color: root.color
  }

  // ── CoOzey ──
  Item {
    anchors.fill: parent
    visible: Theme.cozy && root.solidOn
    NotchRect {
      visible: root.raised
      x: 0; y: root.depth
      width: root.width; height: root.height
      topColor: Theme.shadowInk
      notch: root.notch
    }
    NotchRect { anchors.fill: parent; topColor: root.inkColor; notch: root.notch }
    NotchRect {
      x: 2; y: 2
      width: Math.max(0, root.width - 4); height: Math.max(0, root.height - 4)
      topColor: root.color
      notch: Math.max(0, root.notch - 1)
    }
    Rectangle {          // filo de luz
      visible: root.height >= 20
      x: 2 + root.notch; y: 2
      width: Math.max(0, root.width - 4 - 2 * root.notch); height: 2
      color: Theme.paperShine
    }
  }

  Item { id: body; anchors.fill: parent }
}
