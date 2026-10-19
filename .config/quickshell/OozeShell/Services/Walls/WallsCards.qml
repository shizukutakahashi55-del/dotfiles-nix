// WallsCards — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

Item {
  id: dockArea

  required property var walls
  property real progress: 1
  property real cardRatio: 0.24
  property real hoverLift: 10

  property real cardW: width * cardRatio
  property real cardH: cardW * (9.0 / 16.0)

  implicitHeight: cardH

  MouseArea {
    anchors.fill: parent
    z: -1
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      if (wheelLock.running) return
      const dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
      if (dy === 0) return
      dockArea.walls.step(dy < 0 ? 1 : -1)
      wheelLock.restart()
    }
  }
  Timer { id: wheelLock; interval: 110; repeat: false }

  // ─── ESTADOS VACÍOS ───
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - dockArea.cardH / 2 - height / 2
    visible: dockArea.walls.liveMode && dockArea.walls.liveCount === 0 && !dockArea.walls.liveScanning
    horizontalAlignment: Text.AlignHCenter
    text: Translations.t("wallsNoLive") + "\n" + dockArea.walls.liveFolder
    color: Theme.tint(0.67)
    font.pixelSize: 13
    font.family: Theme.fontFamily
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - dockArea.cardH / 2 - height / 2
    width: parent.width * 0.8
    visible: dockArea.walls.onlineMode && dockArea.walls.onlineCount === 0
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: dockArea.walls.onlineLoading ? Translations.t("wallsOnlineLoading")
        : (dockArea.walls.onlineError === "net" ? Translations.t("wallsOnlineNetError")
        : Translations.t("wallsOnlineEmpty"))
    color: Theme.tint(0.67)
    font.pixelSize: 13
    font.family: Theme.fontFamily
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - dockArea.cardH / 2 - height / 2
    width: parent.width * 0.8
    visible: dockArea.walls.downloadedMode && dockArea.walls.downloadedCount === 0
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: dockArea.walls.downloadedLoading ? Translations.t("wallsOnlineLoading")
        : Translations.t("wallsDownloadedEmpty") + "\n" + dockArea.walls.onlineDir
    color: Theme.tint(0.67)
    font.pixelSize: 13
    font.family: Theme.fontFamily
  }

  // ─── TARJETAS ───
  Repeater {
    model: dockArea.walls.windowSize
    delegate: WallsCard {
      walls: dockArea.walls
      dock: dockArea
      progress: dockArea.progress
      hoverLift: dockArea.hoverLift
    }
  }
}
