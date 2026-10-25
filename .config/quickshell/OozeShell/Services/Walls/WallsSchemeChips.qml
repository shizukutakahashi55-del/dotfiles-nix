// WallsSchemeChips — WALLS

import QtQuick
import "../../COMMON"

Flow {
  id: schemeFlow

  required property var walls
  property int chipHeight: 26
  property int chipPad: 20
  property int fontSize: 10
  property int columns: 0

  readonly property real cellW: schemeFlow.columns > 0
    ? Math.floor((schemeFlow.width - schemeFlow.spacing * (schemeFlow.columns - 1)) / schemeFlow.columns)
    : 0

  spacing: 11

  Repeater {
    model: Theme.schemeOrder.map(i => ({ idx: i, label: schemeFlow.walls.schemes[i].label }))
    delegate: SkinRect {
      id: schemeChip
      required property var modelData
      readonly property bool active: modelData.idx === schemeFlow.walls.schemeIndex
      width: schemeFlow.columns > 0 ? schemeFlow.cellW : chipText.implicitWidth + schemeFlow.chipPad
      height: schemeFlow.chipHeight
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
        width: Math.min(implicitWidth, parent.width - 4)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: modelData.label
        font.pixelSize: schemeFlow.fontSize
        font.family: Theme.fontFamily
        color: schemeChip.active ? Theme.bg : Theme.tint(0.8)
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: schemeFlow.walls.applyScheme(schemeChip.modelData.idx)
      }
    }
  }
}
