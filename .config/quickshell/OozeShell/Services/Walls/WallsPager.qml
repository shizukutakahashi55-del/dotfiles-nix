// WallsPager — WALLS

import QtQuick
import "../../COMMON"

Item {
  id: pager

  required property var walls

  implicitHeight: 32

  Row {
    anchors.centerIn: parent
    spacing: 6
    Repeater {
      model: Math.min(pager.walls.activeModel.count, 15)
      delegate: Rectangle {
        width: index === (pager.walls.currentIndex % 15) ? 18 : 6; height: 6; radius: Theme.cozy ? 0 : 3
        color: index === (pager.walls.currentIndex % 15) ? Theme.primary : Theme.tint(0.25)
        Behavior on width { NumberAnimation { duration: Theme.animDuration(200) } }
      }
    }
  }

  WallsCounter {
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    walls: pager.walls
  }
}
