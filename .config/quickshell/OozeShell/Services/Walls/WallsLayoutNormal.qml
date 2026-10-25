// WallsLayoutNormal — WALLS

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  required property var walls
  property real progress: 1

  implicitHeight: col.implicitHeight + root.walls.pad * 2

  ColumnLayout {
    id: col
    x: 0
    y: root.walls.pad
    width: parent.width
    spacing: 16

    WallsSearchBar {
      id: search
      walls: root.walls
      Layout.fillWidth: true
      Layout.leftMargin: root.walls.pad
      Layout.rightMargin: root.walls.pad
    }

    WallsCards {
      walls: root.walls
      progress: root.progress
      cardRatio: root.walls.cardRatio
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
    }

    WallsHeader {
      walls: root.walls
      showCounter: true
      Layout.fillWidth: true
      Layout.leftMargin: root.walls.pad
      Layout.rightMargin: root.walls.pad
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
    z: 201
    x: root.width - width - root.walls.pad
    y: Math.min(root.walls.pad + search.height + 8, Math.max(4, root.height - height - 4))
  }
}
