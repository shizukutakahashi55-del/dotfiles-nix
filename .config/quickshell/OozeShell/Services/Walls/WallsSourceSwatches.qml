// WallsSourceSwatches — WALLS

import QtQuick
import "../../COMMON"

Row {
  id: sourceRow

  required property var walls
  property int size: 26
  property int fontSize: 10

  readonly property bool shown: !Theme.paletteMode && sourceRow.walls.sourceColors.length > 1

  visible: sourceRow.shown
  spacing: 8

  Repeater {
    model: sourceRow.walls.sourceColors
    delegate: SkinRect {
      id: swatch
      required property string modelData
      required property int index
      readonly property bool active: index === sourceRow.walls.effectiveSourceIndex
      width: sourceRow.size; height: sourceRow.size
      notch: 3
      raised: Theme.cozy && active
      depth: 2
      inkColor: modelData
      color: modelData
      border.color: active ? "#ffffff" : Theme.tint(0.18)
      border.width: active ? 2 : Theme.bw1
      scale: swatchArea.containsMouse && !active ? 1.08 : 1.0
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(120) } }

      Text {
        anchors.centerIn: parent
        text: swatch.index + 1
        font.pixelSize: sourceRow.fontSize
        font.bold: swatch.active
        font.family: Theme.monoFamily
        color: sourceRow.walls.inkOn(swatch.modelData)
        opacity: swatch.active ? 1.0 : 0.7
      }
      MouseArea {
        id: swatchArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sourceRow.walls.applySourceIndex(swatch.index)
      }
    }
  }
}
