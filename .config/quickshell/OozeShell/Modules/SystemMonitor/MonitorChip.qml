import QtQuick
import "../../COMMON"

Rectangle {
  id: root

  property string label: ""
  property bool mono: true
  property color tint: Theme.text

  implicitWidth: chipText.implicitWidth + 16
  implicitHeight: 22
  radius: Math.max(3, Theme.cardRadius - 4)
  color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.07)

  Text {
    id: chipText
    anchors.centerIn: parent
    text: root.label
    color: Theme.subtext
    font.family: root.mono ? Theme.monoFamily : Theme.fontFamily
    font.pixelSize: Theme.fs(10)
  }
}
