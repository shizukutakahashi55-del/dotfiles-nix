// WallsCounter — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

Item {
  id: counter

  required property var walls
  property int pillHeight: 32
  property int fontSize: 11
  property bool plain: false

  implicitWidth: counterText.width + (counter.plain ? 0 : 24)
  implicitHeight: counter.pillHeight

  SkinRect {
    anchors.fill: parent
    visible: !counter.plain
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.ink
    color: Qt.rgba(0, 0, 0, 0.55)
    border.color: Qt.rgba(1, 1, 1, 0.18)
    border.width: Theme.bw1
  }

  Text {
    id: counterText
    anchors.centerIn: parent
    text: (counter.walls.activeModel.count > 0 ? counter.walls.currentIndex + 1 : 0) + " / " + counter.walls.activeModel.count
      + (counter.walls.thumbsGenerating ? "  ·  " + Translations.t("wallsGenerating") : "")
      + (counter.walls.onlineMode && counter.walls.onlineLoading ? "  ·  " + Translations.t("wallsOnlineLoading") : "")
    color: counter.plain ? Theme.tint(0.7) : Qt.rgba(1, 1, 1, 0.75)
    font.pixelSize: counter.fontSize
    font.family: Theme.fontFamily
  }
}
