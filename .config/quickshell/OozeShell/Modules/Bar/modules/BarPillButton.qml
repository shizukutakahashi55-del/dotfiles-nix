// BarPillButton — botón estándar de los módulos de la barra (power, idioma, mpris, audio, batería, menú).

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"

SkinRect {
  id: btn

  property string tip: ""
  property bool active: false
  property real hoverScale: 1.06

  default property alias content: row.data

  signal clicked(var mouse)
  signal scrolled(var wheel)
  signal hoverEntered()
  signal hoverExited()

  Layout.preferredHeight: Theme.barVertical ? Math.max(30, row.implicitHeight + 12) : 30
  Layout.preferredWidth: Theme.barVertical ? 40 : Math.max(34, row.implicitWidth + 16)

  radius: Theme.cardRadius
  raised: Theme.cozy && (area.containsMouse || btn.active)
  depth: 2

  color: (area.containsMouse || btn.active) ? Theme.surface : "transparent"
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

  scale: Theme.cozy ? 1.0 : (area.pressed ? 0.90 : (area.containsMouse ? btn.hoverScale : 1.0))
  Behavior on scale { NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutBack } }

  BarFlow {
    id: row
    anchors.centerIn: parent
    gap: Theme.barVertical ? 1 : 6
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: btn.hoverEntered()
    onExited: btn.hoverExited()
    onClicked: mouse => btn.clicked(mouse)
    onWheel: wheel => btn.scrolled(wheel)
  }
}
