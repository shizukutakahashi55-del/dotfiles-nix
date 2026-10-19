// CatIcon — SETTINGS

import QtQuick
import "../COMMON"

Item {
  id: ci

  property string icon: ""
  property color color: Theme.primary
  property real size: Theme.sfs(15)

  readonly property bool drawn: ci.icon.indexOf("shape:") === 0
  readonly property string kind: ci.drawn ? ci.icon.slice(6) : ""
  readonly property real frameW: Math.round(ci.size * 1.05)
  readonly property real frameH: Math.round(ci.size * 0.82)
  readonly property real stroke: Math.max(1.5, Math.round(ci.size / 9))

  implicitWidth: ci.drawn ? ci.frameW : glyph.implicitWidth
  implicitHeight: ci.drawn ? ci.frameH : glyph.implicitHeight

  Text {
    id: glyph
    visible: !ci.drawn
    anchors.centerIn: parent
    text: ci.drawn ? "" : ci.icon
    color: ci.color
    font.pixelSize: ci.size
    font.family: Theme.monoFamily
  }

  Rectangle {
    id: frame
    visible: ci.drawn
    anchors.centerIn: parent
    width: ci.frameW
    height: ci.frameH
    radius: 2
    color: "transparent"
    border.width: ci.stroke
    border.color: ci.color

    Rectangle {
      visible: ci.kind === "dock"
      width: Math.round(parent.width * 0.5)
      height: Math.max(2, Math.round(parent.height * 0.2))
      radius: height / 2
      x: Math.round((parent.width - width) / 2)
      y: parent.height - ci.stroke - 2 - height
      color: ci.color
    }

    Rectangle {
      visible: ci.kind === "bar"
      x: ci.stroke
      y: ci.stroke
      width: parent.width - ci.stroke * 2
      height: Math.max(3, Math.round(parent.height * 0.3))
      color: ci.color
    }
  }
}
