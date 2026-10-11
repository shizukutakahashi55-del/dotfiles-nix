// FusedTip — tooltip de la barra con la MISMA lógica que los popups.
// Antes cada botón traía un ToolTip de QtQuick.Controls: una cajita flotante 8px debajo, de otro color y sin animación, que no tenía nada que ver con Menu / Network / Audio / Calendario. Ahora es un FusedPanel

import QtQuick
import "../COMMON"

FusedPanel {
  id: tip

  property string text: ""

  property int maxTextWidth: 300

  readonly property int padX: 12
  readonly property int padY: 9


  property real maxDepth: -1

  FontMetrics { id: fm; font: label.font }


  readonly property int maxLines: (tip.maxDepth < 0 || tip.scaleFactor <= 0) ? 0
    : Math.max(1, Math.floor(((tip.maxDepth - tip.glassShift) / tip.scaleFactor - tip.padY * 2)
                             / (fm.lineSpacing * 1.06)))


  // ─── Modo Islas (y Dock) ───────────────────────────────────────


  islandAware: true


  liveContent: true

  readonly property bool tooWideForHang: tip.islandRectLocal !== null
    && tip.scaledWidth + 2 * (tip.islandRadius + Theme.tipFlare) > tip.islandRectLocal.w


  property bool forceFloat: false
  readonly property bool floating: tip.islandStyle === "hang" && (tip.tooWideForHang || tip.forceFloat)


  detached: tip.floating || tip.glassFloat


  fuseFrame: false

  flare: Theme.tipFlare
  bodyRadius: Theme.tipRadius
  duration: Theme.animDuration(Theme.tipMs)

  uiScale: Theme.barScale
  fitScreen: false


  panelWidth: Math.min(tip.maxTextWidth, ruler.implicitWidth) + padX * 2
  contentHeight: label.implicitHeight + padY * 2

  Text {
    id: ruler
    visible: false
    text: tip.text
    font.pixelSize: Theme.fs(11)
    font.family: Theme.fontFamily
  }

  Text {
    id: label
    x: tip.padX
    y: tip.padY
    width: tip.panelWidth - tip.padX * 2
    text: tip.text
    wrapMode: Text.WordWrap
    maximumLineCount: tip.maxLines > 0 ? tip.maxLines : 2147483647
    elide: Text.ElideRight
    color: Theme.text
    font.pixelSize: Theme.fs(11)
    font.family: Theme.fontFamily
  }
}
