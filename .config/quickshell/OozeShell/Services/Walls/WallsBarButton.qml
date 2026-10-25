// WallsBarButton — WALLS

import QtQuick
import "../../COMMON"

SkinRect {
  id: btn

  property string icon: ""
  property string label: ""
  property bool active: false
  property bool badge: false
  property int fontSize: 12
  property int padX: 18
  signal clicked()

  implicitWidth: row.implicitWidth + btn.padX * 2
  notch: 4
  raised: Theme.cozy
  depth: 3
  inkColor: btn.active ? Theme.primary : Theme.ink
  color: btn.active ? Theme.primary : (area.containsMouse ? Theme.tint(0.16) : Theme.bg)
  border.color: Theme.primary
  border.width: 1.5
  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8

    Text {
      visible: btn.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: btn.icon
      font.pixelSize: btn.fontSize + 2
      font.family: Theme.monoFamily
      color: btn.active ? Theme.bg : Theme.primary
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: btn.label
      font.pixelSize: btn.fontSize
      font.family: Theme.fontFamily
      color: btn.active ? Theme.bg : Theme.tint(0.9)
    }
    Rectangle {
      visible: btn.badge
      anchors.verticalCenter: parent.verticalCenter
      width: 7; height: 7
      radius: Theme.cozy ? 0 : 4
      color: btn.active ? Theme.bg : Theme.primary
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
