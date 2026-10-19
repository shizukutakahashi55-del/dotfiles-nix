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
    spacing: 14

    WallsHeader {
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
      Layout.preferredHeight: cardH
    }

    WallsPager {
      walls: root.walls
      Layout.fillWidth: true
      Layout.leftMargin: root.walls.pad
      Layout.rightMargin: root.walls.pad
      Layout.preferredHeight: implicitHeight
    }
  }
}
