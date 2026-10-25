// BarToggle — mini botón para plegar / desplegar un módulo de la barra (mpris, taskbar). Plegado, el módulo queda reducido a un solo ícono.

import QtQuick
import QtQuick.Layouts

Rectangle {
  id: toggle

  property bool collapsed: false
  property bool contentAfter: false
  property string tip: ""

  signal toggled()
  signal hoverEntered()
  signal hoverExited()

  readonly property string glyph: {
    const v = Theme.barVertical
    const towards = toggle.contentAfter ? (v ? "▾" : "▸") : (v ? "▴" : "◂")
    const away    = toggle.contentAfter ? (v ? "▴" : "◂") : (v ? "▾" : "▸")
    return toggle.collapsed ? away : towards
  }


  Layout.preferredWidth: Theme.barVertical ? 30 : 16
  Layout.preferredHeight: Theme.barVertical ? 16 : 30
  Layout.alignment: Qt.AlignCenter

  radius: 8
  color: area.containsMouse ? Theme.surface : "transparent"
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

  scale: area.pressed ? 0.90 : (area.containsMouse ? 1.06 : 1.0)
  Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }

  Text {
    anchors.centerIn: parent
    text: toggle.glyph
    color: Theme.subtext
    font.family: Theme.monoFamily
    font.pixelSize: Theme.fs(20)

    opacity: area.containsMouse ? 1.0 : 0.75
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: toggle.hoverEntered()
    onExited: toggle.hoverExited()
    onClicked: toggle.toggled()
  }
}
