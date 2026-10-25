// LockClock

import QtQuick
import "../../COMMON"

Item {
  id: root

  property real unit: 1
  property date now: new Date()
  property bool use24h: true
  property string clockStyle: "classic"
  property int scalePct: 100

  // ── Medidas ──
  readonly property real k: root.unit * root.scalePct / 100
  readonly property string hh: Qt.formatTime(root.now, root.use24h ? "HH" : "h")
  readonly property string mm: Qt.formatTime(root.now, "mm")
  readonly property int hours: root.now.getHours()
  readonly property int minutes: root.now.getMinutes()
  readonly property color glass: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.62)

  implicitWidth: face.item ? face.item.width : 0
  implicitHeight: face.item ? face.item.height : 0

  // ── Selector de estilo ──
  Loader {
    id: face
    sourceComponent: root.clockStyle === "stacked" ? stacked
                   : root.clockStyle === "mono"    ? mono
                   : root.clockStyle === "boxed"   ? boxed
                   : root.clockStyle === "analog"  ? analog
                   : classic
  }

  // ── Clásico ──
  Component {
    id: classic
    Row {
      spacing: 0
      Text {
        text: root.hh
        color: Theme.primary
        font.pixelSize: Math.round(128 * root.k)
        font.bold: true
        font.family: Theme.titleFamily
      }
      Text {
        text: ":"
        color: Theme.subtext
        font.pixelSize: Math.round(128 * root.k)
        font.bold: true
        font.family: Theme.titleFamily
        bottomPadding: Math.round(8 * root.k)
      }
      Text {
        text: root.mm
        color: Theme.text
        font.pixelSize: Math.round(128 * root.k)
        font.bold: true
        font.family: Theme.titleFamily
      }
    }
  }

  // ── Apilado ──
  Component {
    id: stacked
    Column {
      spacing: -Math.round(34 * root.k)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.hh
        color: Theme.primary
        font.pixelSize: Math.round(150 * root.k)
        font.bold: true
        font.family: Theme.titleFamily
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.mm
        color: Theme.text
        font.pixelSize: Math.round(150 * root.k)
        font.bold: true
        font.family: Theme.titleFamily
      }
    }
  }

  // ── Minimalista ──
  Component {
    id: mono
    Text {
      text: root.hh + ":" + root.mm
      color: Theme.text
      font.pixelSize: Math.round(112 * root.k)
      font.bold: false
      font.letterSpacing: Math.round(4 * root.k)
      font.family: Theme.titleFamily
    }
  }

  // ── Tarjetas ──
  Component {
    id: boxed
    Row {
      spacing: Math.round(14 * root.k)

      Repeater {
        model: [
          { t: root.hh, c: Theme.primary },
          { t: root.mm, c: Theme.text }
        ]

        delegate: SkinRect {
          required property var modelData
          width: Math.round(150 * root.k)
          height: Math.round(176 * root.k)
          radius: Theme.cardRadius
          color: root.glass
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.16)

          Text {
            anchors.centerIn: parent
            text: modelData.t
            color: modelData.c
            font.pixelSize: Math.round(104 * root.k)
            font.bold: true
            font.family: Theme.titleFamily
          }
        }
      }
    }
  }

  // ── Analógico ──
  Component {
    id: analog
    Item {
      id: dial
      readonly property real size: Math.round(260 * root.k)
      implicitWidth: dial.size
      implicitHeight: dial.size
      width: dial.implicitWidth
      height: dial.implicitHeight

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.glass
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
      }

      Repeater {
        model: 12

        delegate: Item {
          required property int index
          readonly property bool major: index % 3 === 0
          anchors.fill: parent
          rotation: index * 30

          Rectangle {
            width: Math.max(2, Math.round((major ? 4 : 2) * root.k))
            height: Math.round((major ? 16 : 9) * root.k)
            radius: width / 2
            color: major ? Theme.primary : Theme.subtext
            x: (parent.width - width) / 2
            y: Math.round(12 * root.k)
          }
        }
      }

      Rectangle {
        width: Math.max(3, Math.round(7 * root.k))
        height: Math.round(dial.size * 0.26)
        radius: width / 2
        color: Theme.text
        x: (dial.width - width) / 2
        y: dial.height / 2 - height
        transformOrigin: Item.Bottom
        rotation: ((root.hours % 12) + root.minutes / 60) * 30
      }

      Rectangle {
        width: Math.max(2, Math.round(5 * root.k))
        height: Math.round(dial.size * 0.38)
        radius: width / 2
        color: Theme.primary
        x: (dial.width - width) / 2
        y: dial.height / 2 - height
        transformOrigin: Item.Bottom
        rotation: root.minutes * 6
      }

      Rectangle {
        width: Math.round(14 * root.k)
        height: width
        radius: width / 2
        color: Theme.primary
        anchors.centerIn: parent
      }
    }
  }
}
