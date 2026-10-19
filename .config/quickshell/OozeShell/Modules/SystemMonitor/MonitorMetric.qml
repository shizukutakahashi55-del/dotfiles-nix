// MonitorMetric — SYSTEM MONITOR

import QtQuick
import "../../COMMON"
import "../Menu"

Item {
  id: root

  property string valueText: ""
  property string unit: ""
  property var history: []
  property color accent: Theme.primary
  property string sub: ""
  property int maxSamples: 60
  property int graphHeight: 56
  property bool unavailable: false

  implicitHeight: col.implicitHeight

  Column {
    id: col
    width: parent.width
    spacing: 8

    Item {
      width: parent.width
      height: valueLabel.implicitHeight

      Text {
        id: valueLabel
        text: root.valueText
        color: root.unavailable ? Theme.subtext : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(30)
        font.bold: true
      }
      Text {
        visible: root.unit !== "" && !root.unavailable
        text: root.unit
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(14)
        anchors.left: valueLabel.right
        anchors.leftMargin: 3
        anchors.baseline: valueLabel.baseline
      }
    }

    Sparkline {
      visible: !root.unavailable
      width: parent.width
      height: root.graphHeight
      values: root.history
      maxSamples: root.maxSamples
      maxValue: 100
      fitData: true
      gradientArea: true
      lineColor: root.accent
      areaAlpha: 0.16
    }

    Text {
      visible: root.sub !== ""
      width: parent.width
      text: root.sub
      elide: Text.ElideRight
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(10)
    }
  }
}
