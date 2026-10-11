// SkinRect.qml — COMMON

import QtQuick


Item {
  id: root
  property color color: Theme.surface
  property real radius: Theme.cardRadius
  property alias border: soft.border
  property bool raised: false
  property int depth: 3
  property int notch: 4
  property color inkColor: Theme.ink
  default property alias content: body.data

  readonly property bool solidOn: root.color.a > 0.02

  // ── OozeSoft ──
  Rectangle {
    id: soft
    anchors.fill: parent
    visible: !Theme.cozy
    radius: root.radius
    color: root.color
  }

  // ── Cristal estilo iOS (solo OozeSoft + Modo Cristal) ──


  Rectangle {
    anchors.fill: parent
    visible: Theme.glassCtl && root.solidOn && soft.border.width === 0
    radius: root.radius
    color: "transparent"
    border.width: 1
    border.color: Theme.glassEdge
  }

  // ── CoOzey ──
  Item {
    anchors.fill: parent
    visible: Theme.cozy && root.solidOn
    NotchRect {
      visible: root.raised
      x: 0; y: root.depth
      width: root.width; height: root.height
      topColor: Theme.shadowInk
      notch: root.notch
    }
    NotchRect { anchors.fill: parent; topColor: root.inkColor; notch: root.notch }
    NotchRect {
      x: 2; y: 2
      width: Math.max(0, root.width - 4); height: Math.max(0, root.height - 4)
      topColor: root.color
      notch: Math.max(0, root.notch - 1)
    }
  }

  Item { id: body; anchors.fill: parent }
}
