// BatteryIcon.qml — BATTERY

import QtQuick
import QtQuick.Shapes
import "../COMMON"


Item {
  id: root

  property real percentage: 1
  property bool charging: false
  property bool full: false
  property bool low: false
  property int iconHeight: 12

  readonly property int bodyW: Math.round(root.iconHeight * 1.9)
  readonly property int nubW: 2
  readonly property int nubH: Math.max(4, Math.round(root.iconHeight * 0.42))
  readonly property int ring: 1
  readonly property int gap: 1
  readonly property int pad: root.ring + root.gap
  readonly property int innerW: root.bodyW - 2 * root.pad
  readonly property int innerH: root.iconHeight - 2 * root.pad
  readonly property real pct: Math.max(0, Math.min(1, root.percentage))


  readonly property color tone: root.low ? Theme.error
                               : (root.charging || root.full) ? Theme.primary
                               : Theme.text
  readonly property int fillW: root.pct <= 0 ? 0
                              : Math.max(2, Math.round(root.innerW * root.pct))

  implicitWidth: root.bodyW + root.nubW + 1
  implicitHeight: root.iconHeight
  width: implicitWidth
  height: implicitHeight


  Rectangle {
    id: body
    x: 0; y: 0
    width: root.bodyW
    height: root.iconHeight
    radius: Theme.cozy ? 0 : 3
    color: Theme.tint(0.08)
    border.width: root.ring
    border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, root.low || root.charging ? 1 : 0.85)
    antialiasing: !Theme.cozy
    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
  }


  Rectangle {
    x: root.bodyW + 1
    y: Math.round((root.iconHeight - root.nubH) / 2)
    width: root.nubW
    height: root.nubH
    radius: Theme.cozy ? 0 : 1
    color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.85)
    antialiasing: !Theme.cozy
  }


  Rectangle {
    x: root.pad
    y: root.pad
    width: root.fillW
    height: root.innerH
    radius: Theme.cozy ? 0 : 1.5
    color: root.tone
    visible: root.fillW > 0
    antialiasing: !Theme.cozy
    Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
  }


  Shape {
    visible: root.charging
    width: 6; height: 10
    x: Math.round((root.bodyW - width) / 2)
    y: Math.round((root.iconHeight - height) / 2)
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 0

      fillColor: Theme.bg
      PathSvg { path: "M 4 0 L 0 6 L 2.6 6 L 2 10 L 6 4 L 3.4 4 Z" }
    }
  }
}
