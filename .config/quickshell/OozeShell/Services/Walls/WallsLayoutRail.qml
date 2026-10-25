// WallsLayoutRail — WALLS
// Columna vertical estrecha pegada al borde de la pantalla: buscador arriba,
// carrusel vertical en medio y controles apilados abajo.

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  required property var walls
  property real progress: 1

  readonly property int pad: 12
  readonly property int gap: 8
  readonly property real innerW: Math.max(0, root.width - root.pad * 2)

  implicitHeight: col.implicitHeight + root.pad * 2

  ColumnLayout {
    id: col
    x: root.pad
    y: root.pad
    width: root.innerW
    spacing: root.gap

    WallsSearchBar {
      id: search
      walls: root.walls
      compact: true
      narrow: true
      Layout.fillWidth: true
    }

    // Online: imágenes / live (en la barra no cabe)
    WallsKindToggle {
      visible: root.walls.onlineMode
      walls: root.walls
      fontSize: 11
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? 28 : 0
    }

    WallsCards {
      id: cards
      walls: root.walls
      progress: root.progress
      vertical: true
      cardAspect: 9.0 / 16.0
      sideLen: 38
      gap: 4
      edgeMargin: 0
      hoverLift: 0
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
    }

    WallsBubble {
      Layout.fillWidth: true
      Layout.preferredHeight: 36

      WallsModeToggle {
        walls: root.walls
        compact: true
        anchors { fill: parent; margins: 5 }
      }
    }

    WallsBubble {
      Layout.fillWidth: true
      Layout.preferredHeight: schemes.childrenRect.height + 14

      WallsSchemeChips {
        id: schemes
        walls: root.walls
        chipHeight: 24
        chipPad: 14
        fontSize: 10
        spacing: 6
        columns: Theme.schemeColumns
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7 }
      }
    }

    Flow {
      id: tools
      spacing: 8
      Layout.fillWidth: true
      Layout.preferredHeight: tools.childrenRect.height

      WallsBubble {
        visible: swatches.shown
        width: swatches.implicitWidth + 14
        height: 36

        WallsSourceSwatches {
          id: swatches
          walls: root.walls
          size: 24
          fontSize: 10
          spacing: 6
          anchors.centerIn: parent
        }
      }

      WallsBubble {
        width: acts.implicitWidth + 14
        height: 36

        WallsActionChips {
          id: acts
          walls: root.walls
          chipHeight: 24
          chipPad: 14
          fontSize: 10
          spacing: 6
          anchors.centerIn: parent
        }
      }

      WallsCounter {
        walls: root.walls
        pillHeight: 36
        fontSize: 10
      }
    }
  }

  // ─── MENÚ DE FILTROS / ORDEN ───
  MouseArea {
    anchors.fill: parent
    z: 200
    enabled: root.walls.popup !== ""
    onClicked: root.walls.popup = ""
  }

  WallsPopup {
    walls: root.walls
    fontSize: 11
    width: root.innerW
    z: 201
    x: root.pad
    y: Math.min(root.pad + search.height + 6, Math.max(4, root.height - height - 4))
  }
}
