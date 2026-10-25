// WallsPanel — WALLS

import QtQuick
import "../../COMMON"

FusedPanel {
  id: panel

  required property var walls

  readonly property bool compactLayout: panel.walls.compact
  readonly property bool railLayout: panel.walls.rail
  readonly property bool listLayout: panel.walls.listview
  // Fullview y List flotan en el centro de la pantalla
  readonly property bool fullviewLayout: panel.walls.fullview || panel.walls.listview
  readonly property bool nearBar: panel.compactLayout ? !Theme.barVertical : Theme.barAtBottom
  readonly property real frameFace: panel.walls.frameFloat ? Math.ceil(Theme.frameThicknessVis) : 0
  readonly property real floatGap: panel.walls.frameFloat ? panel.walls.frameFloatGap : 0

  // ─── POSICIÓN ───
  readonly property bool barOccupies: !Theme.barVertical && !(Theme.pillMode && Theme.pillAutoHidePref)
  readonly property real compactFace: (panel.barOccupies ? Theme.barFace : panel.frameFace) + 10 + panel.floatGap
  readonly property real normalFace: (Theme.barAtBottom ? Theme.barOffset : panel.frameFace) + panel.floatGap

  // Rail: pegado al borde izquierdo o derecho, centrado en vertical
  readonly property real railFace: ((Theme.barVertical && Theme.barPosition === Theme.wallsRailSide) ? Theme.barFace : panel.frameFace)
                                   + 10 + panel.floatGap

  edge: panel.railLayout ? Theme.wallsRailSide
        : (panel.compactLayout && !Theme.barAtBottom ? "top" : "bottom")
  align: "center"

  // Fullview: flota en el centro de la pantalla (distancia al borde inferior = mitad del espacio libre).
  readonly property real fvContentH: body.item ? body.item.implicitHeight : 0
  readonly property real fvScaledH: Math.min(panel.fvContentH * panel.uiScale, Math.max(0, panel.hostHeight - 32))
  readonly property real fullviewFace: Math.max(16, Math.round((panel.hostHeight - panel.fvScaledH) / 2))

  faceOffset: panel.railLayout ? panel.railFace
            : (panel.fullviewLayout ? panel.fullviewFace
            : (panel.compactLayout ? panel.compactFace : panel.normalFace))

  islandAware: !panel.compactLayout && !panel.fullviewLayout && !panel.railLayout
  floatWin: !panel.fullviewLayout && !panel.railLayout && Theme.floatWindows && panel.nearBar
  detached: panel.fullviewLayout || panel.railLayout || panel.compactLayout
            || (Theme.barAtBottom && (panel.parent.detached === true || panel.walls.changing))
            || panel.floatWin || panel.walls.frameFloat

  // ─── TAMAÑO ───
  readonly property real baseWidth: panel.railLayout ? 300
                                  : (panel.listLayout ? Math.min(panel.walls.screenW * 0.55, 980)
                                  : (panel.fullviewLayout ? Math.min(panel.walls.screenW * 0.82, 1600)
                                  : (panel.compactLayout ? Math.min(panel.walls.screenW * 0.62, 1100) : panel.walls.panelW)))

  uiScale: Math.min(Theme.wallsScale / 100, panel.walls.screenW * 0.98 / Math.max(1, panel.baseWidth))
  open: panel.walls.open
  panelWidth: panel.baseWidth
  contentHeight: body.item ? body.item.implicitHeight : 0

  color: panel.walls.fuse(Theme.bg, panel.walls.fusionAlpha)

  Loader {
    id: body
    x: 0
    y: 0
    width: parent.width
    sourceComponent: panel.railLayout ? railComp
                   : (panel.listLayout ? listComp
                   : (panel.fullviewLayout ? fullviewComp : (panel.compactLayout ? compactComp : normalComp)))
  }

  Component {
    id: normalComp
    WallsLayoutNormal { walls: panel.walls; progress: panel.progress }
  }

  Component {
    id: railComp
    WallsLayoutRail { walls: panel.walls; progress: panel.progress }
  }

  Component {
    id: listComp
    WallsLayoutList { walls: panel.walls; progress: panel.progress }
  }

  Component {
    id: fullviewComp
    WallsLayoutFullview { walls: panel.walls; progress: panel.progress }
  }

  Component {
    id: compactComp
    WallsLayoutCompact { walls: panel.walls; progress: panel.progress }
  }
}
