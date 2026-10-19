// WallsSchemeChips — WALLS

import QtQuick
import "../../COMMON"

Flow {
  id: schemeFlow

  required property var walls
  property int chipHeight: 26
  property int chipPad: 20
  property int fontSize: 10

  spacing: 11

  Repeater {
    model: schemeFlow.walls.schemes
    delegate: SkinRect {
      id: schemeChip
      readonly property bool active: index === schemeFlow.walls.schemeIndex
      width: chipText.implicitWidth + schemeFlow.chipPad; height: schemeFlow.chipHeight
      notch: 3
      raised: Theme.cozy && active
      depth: 2
      inkColor: active ? Theme.primary : Theme.ink
      color: active ? Theme.primary : Theme.tint(0.08)
      border.color: active ? "#ffffff" : Theme.tint(0.18)
      border.width: Theme.bw1
      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

      Text {
        id: chipText
        anchors.centerIn: parent
        text: modelData.label
        font.pixelSize: schemeFlow.fontSize
        font.family: Theme.fontFamily
        color: schemeChip.active ? Theme.bg : Theme.tint(0.8)
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: schemeFlow.walls.applyScheme(index)
      }
    }
  }
}
