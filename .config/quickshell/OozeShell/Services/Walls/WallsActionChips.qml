// WallsActionChips — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

Row {
  id: actionsRow

  required property var walls
  property int chipHeight: 26
  property int chipPad: 20
  property int fontSize: 10

  spacing: 8

  SkinRect {
    id: randomChip
    width: randomText.implicitWidth + actionsRow.chipPad; height: actionsRow.chipHeight
    notch: 3
    raised: Theme.cozy
    depth: 2
    inkColor: Theme.ink
    color: randomArea.containsMouse ? Theme.tint(0.16) : Theme.tint(0.08)
    border.color: Theme.tint(0.18); border.width: Theme.bw1
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    Text {
      id: randomText
      anchors.centerIn: parent
      text: "⚄  " + Translations.t("wallsRandom")
      font.pixelSize: actionsRow.fontSize
      font.family: Theme.fontFamily
      color: Theme.tint(0.8)
    }
    MouseArea {
      id: randomArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionsRow.walls.randomIndex()
    }
  }

  SkinRect {
    id: fxChip
    width: fxText.implicitWidth + actionsRow.chipPad; height: actionsRow.chipHeight
    notch: 3
    raised: Theme.cozy && actionsRow.walls.previewOn
    depth: 2
    inkColor: actionsRow.walls.previewOn ? Theme.primary : Theme.ink
    color: actionsRow.walls.previewOn ? Theme.primary : Theme.tint(0.08)
    border.color: actionsRow.walls.previewOn ? "#ffffff" : Theme.tint(0.18)
    border.width: Theme.bw1
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
    Text {
      id: fxText
      anchors.centerIn: parent
      text: "󰈈  " + Translations.t("wallsPreview") + "  " + (actionsRow.walls.previewOn ? "ON" : "OFF")
      font.pixelSize: actionsRow.fontSize
      font.family: Theme.monoFamily
      color: actionsRow.walls.previewOn ? Theme.bg : Theme.tint(0.8)
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: actionsRow.walls.previewOn = !actionsRow.walls.previewOn
    }
  }
}
