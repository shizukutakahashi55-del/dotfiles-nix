// WallsLayoutCompact — WALLS

import QtQuick
import QtQuick.Layouts
import "../../COMMON"

Item {
  id: root

  required property var walls
  property real progress: 1

  readonly property int pad: 12
  readonly property int gap: 8
  readonly property real cardRatio: 0.235
  readonly property bool selectorsFirst: Theme.barAtBottom
  readonly property real innerW: Math.max(0, root.width - root.pad * 2)
  readonly property real fit: header.implicitWidth > root.innerW && header.implicitWidth > 0
                              ? root.innerW / header.implicitWidth : 1
  readonly property real selectorsH: Math.round(header.implicitHeight * root.fit)

  implicitHeight: root.pad * 2 + cards.implicitHeight + root.gap + root.selectorsH

  // ─── SELECTORES ───
  property bool selectorsSettled: false
  property bool selectorsReady: false
  Timer {
    id: settleTimer
    interval: 150
    repeat: false
    onTriggered: { root.selectorsSettled = true; root.selectorsReady = true }
  }
  onFitChanged: {
    if (!root.selectorsSettled) { root.selectorsReady = false; settleTimer.restart() }
  }
  Component.onCompleted: settleTimer.restart()
  Item {
    id: selectors
    x: root.pad
    y: root.selectorsFirst ? root.pad : root.pad + cards.implicitHeight + root.gap
    width: root.innerW
    height: root.selectorsH
    opacity: root.selectorsReady ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    WallsHeader {
      id: header
      walls: root.walls
      compact: true
      showCounter: true
      width: Math.max(root.innerW, header.implicitWidth)
      x: (selectors.width - width * root.fit) / 2
      scale: root.fit
      transformOrigin: Item.TopLeft
    }
  }

  // ─── TARJETAS ───
  WallsCards {
    id: cards
    x: root.pad
    y: root.selectorsFirst ? root.pad + root.selectorsH + root.gap : root.pad
    width: root.innerW
    walls: root.walls
    progress: root.progress
    cardRatio: root.cardRatio
    hoverLift: 6
  }
}
