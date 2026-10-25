// WallsCards — WALLS

import QtQuick
import "../Lang"
import "../../COMMON"

Item {
  id: dockArea

  required property var walls
  property real progress: 1
  property real cardRatio: 0.34
  property real hoverLift: 10
  property real edgeMargin: 20
  property real gap: 6
  property real skew: 0

  // Vertical: las tarjetas se apilan en columna. cardW = ancho de la columna (todas las tarjetas),
  // cardH = alto de la tarjeta actual, sideLen = alto de cada tarjeta lateral.
  property bool vertical: false
  property real cardAspect: 9.0 / 16.0
  property real sideLen: 40

  readonly property int half: dockArea.walls.halfWindow
  property real cardW: dockArea.vertical ? width : width * cardRatio
  property real cardH: cardW * cardAspect
  property real sideW: dockArea.vertical ? cardW
    : Math.max(40, (width - dockArea.edgeMargin * 2 - dockArea.cardW - dockArea.gap * dockArea.half * 2) / (dockArea.half * 2))
  property real sideH: dockArea.sideLen

  readonly property real emptyY: dockArea.vertical ? height / 2 : height - cardH / 2

  implicitHeight: dockArea.vertical
    ? dockArea.edgeMargin * 2 + cardH + (sideH + gap) * half * 2
    : cardH + hoverLift

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
    y: dockArea.emptyY - height / 2
    width: parent.width * 0.8
    visible: dockArea.walls.liveMode && dockArea.walls.liveCount === 0 && !dockArea.walls.liveScanning
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: Translations.t("wallsNoLive") + "\n" + dockArea.walls.liveFolder
    color: Theme.tint(0.67)
    font.pixelSize: 13
    font.family: Theme.fontFamily
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: dockArea.emptyY - height / 2
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
    y: dockArea.emptyY - height / 2
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

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: dockArea.emptyY - height / 2
    width: parent.width * 0.8
    visible: dockArea.walls.searchEmpty
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: Translations.t("wallsNoResults")
    color: Theme.tint(0.67)
    font.pixelSize: 13
    font.family: Theme.fontFamily
  }

  // ─── PRECARGA ───
  // Mantiene en la caché de imágenes las miniaturas vecinas a la ventana visible.
  // Sin esto, al retroceder cada tarjeta recibe la imagen que la tarjeta anterior acaba de
  // soltar; si esa imagen es grande, la caché de Qt la descarta y hay que decodificarla otra vez.
  // Las Image con referencia viva nunca se descartan. Debe usar el mismo sourceSize que WallsCard.
  Repeater {
    model: (dockArea.walls.open && dockArea.walls.activeModel.count > 0) ? (dockArea.half + 2) * 2 + 1 : 0
    delegate: Image {
      required property int index
      readonly property int off: index - (dockArea.half + 2)
      readonly property int total: dockArea.walls.activeModel.count
      readonly property var wp: {
        dockArea.walls.thumbRev
        dockArea.walls.liveMode
        dockArea.walls.downloadedMode
        return total > 0
          ? dockArea.walls.activeModel.get(((dockArea.walls.currentIndex + off) % total + total) % total)
          : null
      }
      width: 1
      height: 1
      opacity: 0
      enabled: false
      source: (wp && wp.ready) ? ("file://" + wp.thumb) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      sourceSize.width: Math.round(dockArea.cardW * 1.3)
    }
  }

  // ─── TARJETAS ───
  Repeater {
    model: dockArea.walls.windowSize
    delegate: WallsCard {
      walls: dockArea.walls
      dock: dockArea
      progress: dockArea.progress
      hoverLift: dockArea.hoverLift
      skew: dockArea.skew
    }
  }
}
