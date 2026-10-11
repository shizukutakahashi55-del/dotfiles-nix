// SysInfoWidget — CPU · RAM · GPU. Estilos: bars · rings · graph

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import ".."
import "../../COMMON"
import "../../MENU"

WidgetBase {
  id: w

  // ── fuente de datos (se destruye con la ventana) ──
  readonly property int histN: 40
  SystemStats {
    id: stats
    active: w.widgetId !== ""
    intervalMs: w.opt("intervalMs", 1000)
    maxSamples: w.histN
  }

  readonly property string sty: w.widgetStyle
  readonly property var keys: ["cpu", "ram", "gpu"]

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function shifted(c, d) {
    const h = c.hslHue < 0 ? 0 : c.hslHue
    return Qt.hsla((h + d + 1) % 1, Math.max(0.35, c.hslSaturation),
                   Math.max(0.5, Math.min(0.72, c.hslLightness)), 1)
  }

  function titleOf(k) { return k.toUpperCase() }
  function iconOf(k) { return k === "cpu" ? OozeIcons.cpu : k === "ram" ? OozeIcons.memory : OozeIcons.gpu }
  function accentOf(k) {
    return k === "cpu" ? Theme.primary : k === "ram" ? w.shifted(Theme.primary, 0.12) : w.shifted(Theme.primary, -0.12)
  }
  function okOf(k) { return k !== "gpu" || stats.gpu >= 0 }
  function valueOf(k) {
    const v = k === "cpu" ? stats.cpu : k === "ram" ? stats.ram : stats.gpu
    return Math.max(0, Math.min(1, v / 100))
  }

  function toneOf(k) { return (w.okOf(k) && w.valueOf(k) >= 0.85) ? Theme.error : w.accentOf(k) }

  function histOf(k) {
    const h = k === "cpu" ? stats.cpuHistory : k === "ram" ? stats.ramHistory : stats.gpuHistory
    const out = []
    for (let i = 0; i < h.length; i++) out.push(Math.max(0, Math.min(1, h[i] / 100)))
    return out
  }
  function pctOf(k) { return w.okOf(k) ? Math.round(w.valueOf(k) * 100) + "%" : "n/d" }
  function detailOf(k) {
    if (k === "ram") return stats.ramUsedGb.toFixed(1) + " / " + stats.ramTotalGb.toFixed(1) + " GB"
    return w.pctOf(k)
  }

  function subOf(k) {
    if (k === "ram") return stats.ramTotalGb > 0 ? stats.ramUsedGb.toFixed(1) + "/" + stats.ramTotalGb.toFixed(0) + "G" : ""
    const t = k === "cpu" ? stats.cpuTemp : stats.gpuTemp
    return t >= 0 ? Math.round(t) + "°C" : ""
  }

  // ── fondo de tarjeta ──
  WidgetCard {
    anchors.fill: parent
    visible: w.opt("card", true)
    alpha: w.opt("bgOpacity", 72) / 100
  }

  // ── piezas compartidas ──

  component IconChip: Rectangle {
    id: chip
    property string icon: ""
    property color tone: Theme.primary
    property real box: 22
    implicitWidth: chip.box; implicitHeight: chip.box
    radius: Theme.cozy ? 3 : Math.round(chip.box * 0.34)
    color: Qt.alpha(chip.tone, Theme.cozy ? 0.32 : 0.20)
    Text {
      anchors.centerIn: parent
      text: chip.icon
      color: chip.tone
      font.family: Theme.monoFamily
      font.pixelSize: Math.round(chip.box * 0.58)
    }
  }


  component Gauge: Item {
    id: gg
    property real value: 0
    property bool ok: true
    property color tone: Theme.primary
    property real shown: gg.ok ? gg.value : 0
    Behavior on shown { NumberAnimation { duration: Theme.animDuration(450); easing.type: Easing.OutCubic } }

    readonly property real size: Math.max(24, Math.min(gg.width, gg.height))
    readonly property real stroke: Math.max(4, Math.round(gg.size * 0.11))

    PixelRing {
      visible: Theme.cozy
      anchors.centerIn: parent
      width: gg.size; height: gg.size
      value: gg.shown * 100
      segments: 24
      cell: Math.max(4, Math.round(gg.size / 10))
      color: gg.tone
      track: Qt.alpha(gg.tone, 0.16)
    }
    Rectangle {
      visible: !Theme.cozy
      anchors.centerIn: parent
      width: gg.size; height: gg.size
      radius: width / 2
      color: "transparent"
      border.width: gg.stroke
      border.color: Qt.alpha(gg.tone, 0.16)
    }
    Shape {
      id: arc
      visible: !Theme.cozy
      anchors.centerIn: parent
      width: gg.size; height: gg.size
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: gg.shown > 0.004 ? gg.tone : "transparent"
        strokeWidth: gg.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: arc.width / 2; centerY: arc.height / 2
          radiusX: (arc.width - gg.stroke) / 2; radiusY: (arc.height - gg.stroke) / 2
          startAngle: -90
          sweepAngle: 359.9 * Math.max(0, Math.min(1, gg.shown))
        }
      }
    }
    Text {
      anchors.centerIn: parent
      text: gg.ok ? Math.round(gg.value * 100) + "%" : "n/d"
      color: Theme.text
      font.family: Theme.fontFamily; font.bold: true
      font.pixelSize: Math.max(9, Math.round(gg.size / 4.4))
    }
  }


  component Spark: Item {
    id: sp
    property var hist: []
    property int maxN: 40
    property color tone: Theme.primary
    clip: true

    readonly property var pts: {
      const n = sp.hist.length
      const out = []
      if (n < 2 || sp.width <= 0 || sp.height <= 0) return out
      const step = sp.width / (sp.maxN - 1)
      const pad = 2
      for (let i = 0; i < n; i++) {
        const x = sp.width - (n - 1 - i) * step
        const y = pad + (sp.height - 2 * pad) * (1 - Math.max(0, Math.min(1, sp.hist[i])))
        out.push(Qt.point(x, y))
      }
      return out
    }
    readonly property var areaPts: {
      const p = sp.pts
      if (p.length < 2) return []
      return [Qt.point(p[0].x, sp.height)].concat(p).concat([Qt.point(p[p.length - 1].x, sp.height)])
    }

    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: "transparent"
        fillColor: Qt.alpha(sp.tone, 0.22)
        PathPolyline { path: sp.areaPts }
      }
      ShapePath {
        strokeColor: sp.tone
        strokeWidth: 1.8
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        PathPolyline { path: sp.pts }
      }
    }
  }

  // ═════════ bars ═════════

  ColumnLayout {
    visible: w.sty === "bars"
    anchors { fill: parent; margins: 14 }
    spacing: 8

    Repeater {
      model: w.sty === "bars" ? w.keys : []
      delegate: ColumnLayout {
        id: row
        required property string modelData
        readonly property color tone: w.toneOf(modelData)
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 5

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          IconChip { box: 22; icon: w.iconOf(row.modelData); tone: row.tone }
          Text {
            text: w.titleOf(row.modelData)
            color: Theme.text
            font.family: Theme.fontFamily; font.bold: true
            font.pixelSize: Theme.fs(12)
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            Layout.preferredHeight: 20
            Layout.preferredWidth: Math.max(34, detailText.implicitWidth + 16)
            radius: 10
            color: w.withAlpha(row.tone, 0.16)
            Text {
              id: detailText
              anchors.centerIn: parent
              text: w.detailOf(row.modelData)
              color: row.tone
              font.family: Theme.fontFamily
              font.bold: true
              font.pixelSize: Theme.fs(10)
            }
          }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 8
          radius: 4
          clip: true
          color: w.withAlpha(row.tone, 0.16)
          Rectangle {
            height: parent.height; radius: 4
            width: Math.min(parent.width, parent.width * (w.okOf(row.modelData) ? w.valueOf(row.modelData) : 0))
            color: row.tone
            Behavior on width { NumberAnimation { duration: Theme.animDuration(400); easing.type: Easing.OutCubic } }
          }
          Rectangle {
            visible: w.okOf(row.modelData)
            width: 10
            height: 10
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * w.valueOf(row.modelData) - width / 2))
            color: row.tone
            border.width: 2
            border.color: Theme.bg
          }
        }
      }
    }
  }

  // ═════════ rings ═════════

  RowLayout {
    visible: w.sty === "rings"
    anchors { fill: parent; margins: 12 }
    spacing: 8

    Repeater {
      model: w.sty === "rings" ? w.keys : []
      delegate: WidgetCard {
        id: tile
        required property string modelData
        readonly property color tone: w.toneOf(modelData)
        readonly property bool tall: height >= 118
        readonly property bool wide: width >= 96
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        tile: true
        alpha: 0.9
        scaleRadius: 1


        Rectangle {
          visible: !Theme.cozy
          anchors.fill: parent
          anchors.margins: 1
          radius: Math.max(0, tile.radius - 1)
          gradient: Gradient {
            GradientStop { position: 0.0; color: w.withAlpha(tile.tone, 0.18) }
            GradientStop { position: 0.55; color: w.withAlpha(tile.tone, 0.04) }
            GradientStop { position: 1.0; color: "transparent" }
          }
        }

        ColumnLayout {
          anchors { fill: parent; margins: 8 }
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 5
            IconChip { box: 20; icon: w.iconOf(tile.modelData); tone: tile.tone }
            Text {
              visible: tile.wide
              text: w.titleOf(tile.modelData)
              color: Theme.text
              font.family: Theme.fontFamily; font.bold: true
              font.pixelSize: Theme.fs(11)
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
          Gauge {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 28
            value: w.valueOf(tile.modelData)
            ok: w.okOf(tile.modelData)
            tone: tile.tone
          }
          Text {
            visible: tile.tall && text !== ""
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: w.subOf(tile.modelData)
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // ═════════ graph ═════════


  ColumnLayout {
    visible: w.sty === "graph"
    anchors { fill: parent; margins: 12 }
    spacing: 8

    Repeater {
      model: w.sty === "graph" ? w.keys : []
      delegate: RowLayout {
        id: grow
        required property string modelData
        readonly property color tone: w.toneOf(modelData)
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 1
        spacing: 10

        RowLayout {
          Layout.preferredWidth: Math.max(78, Math.round(grow.width * 0.26))
          Layout.maximumWidth: Math.round(grow.width * 0.4)
          spacing: 7
          IconChip { box: Math.min(24, Math.max(18, grow.height * 0.6)); icon: w.iconOf(grow.modelData); tone: grow.tone }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              text: w.titleOf(grow.modelData)
              color: Theme.subtext
              font.family: Theme.fontFamily; font.bold: true
              font.pixelSize: Theme.fs(10)
            }
            Text {
              Layout.fillWidth: true
              text: w.detailOf(grow.modelData)
              color: Theme.text
              font.family: Theme.fontFamily; font.bold: true
              font.pixelSize: Theme.fs(12)
              elide: Text.ElideRight
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Theme.cozy ? 3 : 8
          clip: true
          color: w.withAlpha(grow.tone, 0.12)
          Spark {
            anchors { fill: parent; margins: 3 }
            visible: w.okOf(grow.modelData)
            hist: w.histOf(grow.modelData)
            maxN: w.histN
            tone: grow.tone
          }
          Text {
            visible: !w.okOf(grow.modelData)
            anchors.centerIn: parent
            text: "n/d"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
          }
        }
      }
    }
  }
}
