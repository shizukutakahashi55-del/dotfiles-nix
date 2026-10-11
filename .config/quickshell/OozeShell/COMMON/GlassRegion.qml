// GlassRegion — región de blur (ext-background-effect-v1) de una ventana.
// El compositor difumina lo que hay DETRÁS de la región (ventanas incluidas; para que no sea un blur "xray" que solo ve el wallpaper, ver docs/GLASS.md). La región es la silueta exacta de cada panel: ni la ventana enter…

import Quickshell
import QtQuick

Region {
  id: root

  property var panels: []

  property Item rect: null
  property bool rectOn: false
  property real rectRadius: 0

  component PanelSlot: Region {
    property var p: null
    readonly property bool on: p !== null && p !== undefined && p.blurOn === true
    x: on ? Math.round(p.blurX) : 0
    y: on ? Math.round(p.blurY) : 0
    width: on ? Math.max(0, Math.round(p.blurW)) : 0
    height: on ? Math.max(0, Math.round(p.blurH)) : 0
    topLeftRadius: on ? p.blurTL : 0
    topRightRadius: on ? p.blurTR : 0
    bottomLeftRadius: on ? p.blurBL : 0
    bottomRightRadius: on ? p.blurBR : 0
  }

  PanelSlot { p: root.panels.length > 0 ? root.panels[0] : null }
  PanelSlot { p: root.panels.length > 1 ? root.panels[1] : null }
  PanelSlot { p: root.panels.length > 2 ? root.panels[2] : null }
  PanelSlot { p: root.panels.length > 3 ? root.panels[3] : null }

  Region {
    x: (root.rectOn && root.rect) ? Math.round(root.rect.x) : 0
    y: (root.rectOn && root.rect) ? Math.round(root.rect.y) : 0
    width: (root.rectOn && root.rect) ? Math.round(root.rect.width) : 0
    height: (root.rectOn && root.rect) ? Math.round(root.rect.height) : 0
    radius: root.rectRadius
  }
}
