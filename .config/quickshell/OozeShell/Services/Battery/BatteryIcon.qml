// BatteryIcon.qml — BATTERY

import QtQuick
import QtQuick.Shapes
import "../../COMMON"


Item {
  id: root

  property real percentage: 1
  property bool charging: false
  property bool full: false
  property bool low: false
  property int iconHeight: 12
  property bool showPercent: true

  // ── Medidas ──
  readonly property int bodyH: root.showPercent ? Math.max(root.iconHeight + 6, 18) : root.iconHeight
  readonly property int bodyW: Math.round(root.bodyH * (root.showPercent ? 1.8 : 1.9))
  readonly property int nubW: Math.max(2, Math.round(root.bodyH * 0.13))
  readonly property int nubH: Math.max(5, Math.round(root.bodyH * 0.4))
  readonly property int ring: 1
  readonly property int pad: 2
  readonly property int boltSlot: root.charging ? Math.max(7, Math.round(root.bodyH * 0.46)) : 0
  readonly property int innerW: root.bodyW - 2 * root.pad
  readonly property int innerH: root.bodyH - 2 * root.pad
  readonly property real pct: Math.max(0, Math.min(1, root.percentage))
  readonly property real corner: Theme.cozy ? 0 : Math.round(root.bodyH * 0.34)

  // ── Colores ──
  readonly property color tone: root.low ? Theme.error
                               : (root.charging || root.full) ? Theme.primary
                               : Theme.text
  readonly property color onTone: root.low ? Theme.textOnError
                                 : (root.charging || root.full) ? Theme.textOnPrimary
                                 : Theme.bg
  readonly property int fillW: root.pct <= 0 ? 0
                              : Math.max(3, Math.round(root.innerW * root.pct))
  readonly property string label: String(Math.round(root.pct * 100))
  readonly property int labelPx: Math.max(8, Math.round(root.bodyH * 0.6))

  implicitWidth: root.boltSlot + root.bodyW + root.nubW + 1
  implicitHeight: root.bodyH
  width: implicitWidth
  height: implicitHeight

  // ── Rayo de carga ──
  Shape {
    visible: root.charging
    width: root.boltSlot - 1
    height: Math.round(root.bodyH * 0.62)
    y: Math.round((root.bodyH - height) / 2)
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      fillColor: Theme.primary

      PathSvg { path: "M 4 0 L 0 6 L 2.6 6 L 2 10 L 6 4 L 3.4 4 Z" }
    }
    transform: Scale {
      xScale: (root.boltSlot - 1) / 6
      yScale: Math.round(root.bodyH * 0.62) / 10
    }
  }

  // ── Cuerpo ──
  Rectangle {
    id: body
    x: root.boltSlot
    y: 0
    width: root.bodyW
    height: root.bodyH
    radius: root.corner
    color: Theme.tint(0.08)
    border.width: root.ring
    border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, root.low || root.charging ? 1 : 0.85)
    antialiasing: !Theme.cozy
    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }
  }

  // ── Polo ──
  Rectangle {
    x: root.boltSlot + root.bodyW + 1
    y: Math.round((root.bodyH - root.nubH) / 2)
    width: root.nubW
    height: root.nubH
    radius: Theme.cozy ? 0 : root.nubW / 2
    color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.85)
    antialiasing: !Theme.cozy
  }

  // ── Relleno ──
  Rectangle {
    x: root.boltSlot + root.pad
    y: root.pad
    width: root.fillW
    height: root.innerH
    radius: Theme.cozy ? 0 : Math.max(1, root.corner - root.pad)
    color: root.tone
    visible: root.fillW > 0
    antialiasing: !Theme.cozy
    Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
  }

  // ── Porcentaje dentro de la batería ──
  Item {
    id: numbers
    visible: root.showPercent
    x: root.boltSlot
    width: root.bodyW
    height: root.bodyH

    Text {
      anchors.centerIn: parent
      text: root.label
      color: Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: root.labelPx
    }

    Item {
      x: 0
      width: root.pad + root.fillW
      height: parent.height
      clip: true
      Behavior on width { NumberAnimation { duration: Theme.animDuration(200); easing.type: Easing.OutCubic } }

      Text {
        x: (numbers.width - width) / 2
        y: (numbers.height - height) / 2
        text: root.label
        color: root.onTone
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: root.labelPx
      }
    }
  }
}
