// WallsPanel — WALLS

import QtQuick
import "../../COMMON"

FusedPanel {
  id: panel

  required property var walls

  readonly property bool compactLayout: panel.walls.compact
  readonly property bool nearBar: panel.compactLayout ? !Theme.barVertical : Theme.barAtBottom
  readonly property real frameFace: panel.walls.frameFloat ? Math.ceil(Theme.frameThicknessVis) : 0
  readonly property real floatGap: panel.walls.frameFloat ? panel.walls.frameFloatGap : 0

  // ─── POSICIÓN ───
  readonly property bool barOccupies: !Theme.barVertical && !(Theme.pillMode && Theme.pillAutoHidePref)
  readonly property real compactFace: (panel.barOccupies ? Theme.barFace : panel.frameFace) + 10 + panel.floatGap
  readonly property real normalFace: (Theme.barAtBottom ? Theme.barOffset : panel.frameFace) + panel.floatGap

  edge: panel.compactLayout && !Theme.barAtBottom ? "top" : "bottom"
  align: "center"

  faceOffset: panel.compactLayout ? panel.compactFace : panel.normalFace

  islandAware: !panel.compactLayout
  floatWin: Theme.floatWindows && panel.nearBar
  detached: panel.compactLayout
            || (Theme.barAtBottom && (panel.parent.detached === true || panel.walls.changing))
            || panel.floatWin || panel.walls.frameFloat

  // ─── TAMAÑO ───
  readonly property real baseWidth: panel.compactLayout ? Math.min(panel.walls.screenW * 0.62, 1100) : panel.walls.panelW

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
    sourceComponent: panel.compactLayout ? compactComp : normalComp
  }

  Component {
    id: normalComp
    WallsLayoutNormal { walls: panel.walls; progress: panel.progress }
  }

  Component {
    id: compactComp
    WallsLayoutCompact { walls: panel.walls; progress: panel.progress }
  }
}
