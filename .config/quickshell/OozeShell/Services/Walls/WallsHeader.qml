// WallsHeader — WALLS

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

RowLayout {
  id: header

  required property var walls
  property bool compact: false
  property bool showCounter: false

  readonly property int bubblePad: header.compact ? 12 : 20

  spacing: header.compact ? 8 : 10

  Item { Layout.fillWidth: true }

  // ─── BOTÓN Static / Live / Online / Downloaded ──────────
  SkinRect {
    id: modeBubble
    Layout.preferredWidth: modeToggle.width + header.bubblePad
    Layout.preferredHeight: schemeChips.implicitHeight + header.bubblePad
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: 1.5

    WallsModeToggle {
      id: modeToggle
      walls: header.walls
      compact: header.compact
      anchors.centerIn: parent
    }
  }

  // ─── SELECTOR DE ESQUEMAS ──────────────────────────
  SkinRect {
    id: topBar
    Layout.preferredWidth: header.compact ? schemeChips.implicitWidth + header.bubblePad
                                          : Math.min(500, (header.width + header.walls.pad * 2) * 0.5)
    Layout.preferredHeight: schemeChips.implicitHeight + header.bubblePad
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: 1.5

    WallsSchemeChips {
      id: schemeChips
      walls: header.walls
      chipHeight: header.compact ? 24 : 26
      chipPad: header.compact ? 16 : 20
      fontSize: 10
      spacing: header.compact ? 6 : 11
      anchors.centerIn: parent
    }
  }

  // ─── COLORES DE MATUGEN (1…x) ───────────────────────
  SkinRect {
    id: sourceBubble
    visible: swatches.shown
    Layout.preferredWidth: visible ? swatches.implicitWidth + header.bubblePad : 0
    Layout.preferredHeight: schemeChips.implicitHeight + header.bubblePad
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: 1.5

    WallsSourceSwatches {
      id: swatches
      walls: header.walls
      size: header.compact ? 24 : 26
      fontSize: 10
      spacing: header.compact ? 6 : 8
      anchors.centerIn: parent
    }
  }

  // ─── ACCIONES: aleatorio + vista previa ─────────────
  SkinRect {
    id: actionsBubble
    Layout.preferredWidth: actions.implicitWidth + header.bubblePad
    Layout.preferredHeight: schemeChips.implicitHeight + header.bubblePad
    notch: 4
    raised: Theme.cozy
    depth: 3
    inkColor: Theme.primary
    color: Theme.bg
    border.color: Theme.primary
    border.width: 1.5

    WallsActionChips {
      id: actions
      walls: header.walls
      chipHeight: header.compact ? 24 : 26
      chipPad: header.compact ? 16 : 20
      fontSize: 10
      spacing: header.compact ? 6 : 8
      anchors.centerIn: parent
    }
  }

  // ─── CONTADOR ───────────────────────────────────────
  WallsCounter {
    visible: header.showCounter
    walls: header.walls
    pillHeight: schemeChips.implicitHeight + header.bubblePad
    fontSize: 10
  }

  Item { Layout.fillWidth: true }
}
