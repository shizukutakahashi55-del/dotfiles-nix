// MdCover — COMMON

import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string source: ""
  property string shape: "cookie12"
  property string glyph: "󰎆"
  property color tone: Theme.primary
  property color backdrop: MdTokens.containerHigh
  property int decodeSize: 256
  property bool dimmed: false
  readonly property bool ready: img.status === Image.Ready && !Theme.shellPerf

  implicitWidth: 56
  implicitHeight: 56

  Item {
    id: silhouette
    anchors.fill: parent
    layer.enabled: !Theme.shellPerf
    visible: false

    MdShape {
      anchors.fill: parent
      shape: root.shape
      color: "black"
    }
  }

  MdShape {
    anchors.fill: parent
    visible: Theme.shellPerf
    shape: root.shape
    color: root.backdrop
  }

  Item {
    id: photo
    anchors.fill: parent
    visible: !Theme.shellPerf
    opacity: root.dimmed ? 0.55 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(200) } }

    layer.enabled: !Theme.shellPerf
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: silhouette
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }

    Rectangle {
      anchors.fill: parent
      color: root.backdrop
    }

    Image {
      id: img
      anchors.fill: parent
      source: Theme.shellPerf ? "" : root.source
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
      cache: false
      sourceSize: Qt.size(root.decodeSize, root.decodeSize)
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: !root.ready
    text: root.glyph
    color: root.tone
    font.family: Theme.monoFamily
    font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.42)
  }
}
