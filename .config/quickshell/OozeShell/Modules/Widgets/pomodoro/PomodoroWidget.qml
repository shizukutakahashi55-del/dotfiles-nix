// PomodoroWidget — temporizador Pomodoro (enfoque · descanso corto · descanso largo).

import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import ".."
import "../../../COMMON"
import "../../../Services/Lang"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property bool showBg: w.opt("background", true)
  readonly property real bgAlpha: Math.max(0, Math.min(100, Number(w.opt("bgOpacity", 60)))) / 100

  // ── estado (reactivo: view() lee el servicio) ──
  readonly property var v: PomodoroService.view(w.widgetId)
  readonly property string phase: w.v.phase
  readonly property int secs: Math.ceil(w.v.remainMs / 1000)
  function p2(n) { return (n < 10 ? "0" : "") + n }
  readonly property string timeStr: w.p2(Math.floor(w.secs / 60)) + ":" + w.p2(w.secs % 60)
  readonly property string phaseLabel: Translations.t(w.phase === "focus" ? "wgPomoFocus"
                                       : (w.phase === "short" ? "wgPomoShort" : "wgPomoLong"))
  readonly property string roundStr: w.v.round + "/" + w.v.rounds


  readonly property color tone: w.phase === "focus" ? Theme.primary
                               : (w.phase === "short" ? "#6fcf97" : "#56b6e8")
  readonly property color tomatoTone: w.phase === "focus" ? "#e5483b"
                                     : (w.phase === "short" ? "#4caf7a" : "#3d9be0")


  readonly property int doneCount: w.phase === "focus" ? w.v.round - 1
                                  : (w.phase === "short" ? w.v.round : w.v.rounds)


  property real shownRemain: w.v.totalMs > 0 ? w.v.remainMs / w.v.totalMs : 1
  property real shownProg: 1 - w.shownRemain

  readonly property real u: Math.min(w.width, w.height)

  // ── botones: tamaño y sitio según el estilo ──
  readonly property real btnS: {
    switch (w.sty) {
    case "minimal": return Math.max(22, Math.min(34, w.height * 0.28))
    case "bar":     return Math.max(22, Math.min(34, w.height * 0.24))
    case "dots":    return Math.max(22, Math.min(32, w.height * 0.17))
    case "tomato":  return Math.max(22, Math.min(32, w.height * 0.12))
    case "capsule": return Math.max(22, Math.min(34, w.height * 0.34))
    default:        return Math.max(22, Math.min(34, w.u * 0.13))
    }
  }
  readonly property real gap: Math.round(w.btnS * 0.22)
  readonly property real ctlW: 3 * w.btnS + 2 * w.gap
  readonly property real ctlX: (w.sty === "minimal" || w.sty === "bar" || w.sty === "capsule") ? w.width - w.ctlW - 16
                                                                       : (w.width - w.ctlW) / 2
  readonly property real ctlY: {
    switch (w.sty) {
    case "minimal": return (w.height - w.btnS) / 2
    case "capsule": return (w.height - w.btnS) / 2
    case "bar":     return (w.height - w.btnS) / 2 - 6
    case "dots":    return w.height - w.btnS - 12
    case "tomato":  return w.height - w.btnS - 10
    default:        return w.height / 2 + Math.max(40, w.u - 28) * 0.14
    }
  }


  readonly property Item inputArea: ctl

  // ── piezas ──
  component CtlBtn: Rectangle {
    id: b
    property real size: 30
    property string icon: ""
    property bool primary: false
    property color tone: Theme.primary
    signal clicked()

    width: b.size; height: b.size; radius: b.size / 2
    color: b.primary ? (ma.containsMouse ? Qt.lighter(b.tone, 1.12) : b.tone)
                     : (ma.containsMouse ? Theme.surfaceHigh
                                         : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85))
    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: b.icon
      color: b.primary ? Theme.bg : Theme.text
      font.family: Theme.monoFamily
      font.pixelSize: Math.round(b.size * 0.52)
    }
    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: b.clicked()
    }
  }


  component Ring: MdWavyRing {
    property real stroke: 10
    running: w.v.running
    thickness: stroke
    amplitude: Math.max(1.4, stroke * 0.3)
    waveLength: Math.max(14, stroke * 2.6)
    trackColor: Qt.alpha(tone, 0.18)
  }

  component MiniTomato: Item {
    id: mt
    property color tone: "#e5483b"
    Rectangle {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: mt.height * 0.86
      radius: height / 2
      color: mt.tone
    }
    Rectangle {
      width: mt.width * 0.14; height: mt.height * 0.2; radius: width / 2
      x: (mt.width - width) / 2; y: 0
      color: "#3f8f45"
    }
    Rectangle {
      width: mt.width * 0.34; height: mt.height * 0.14; radius: height / 2
      x: mt.width / 2 - width + mt.width * 0.04; y: mt.height * 0.1
      rotation: -18; transformOrigin: Item.Right
      color: "#4caf50"
    }
    Rectangle {
      width: mt.width * 0.34; height: mt.height * 0.14; radius: height / 2
      x: mt.width / 2 - mt.width * 0.04; y: mt.height * 0.1
      rotation: 18; transformOrigin: Item.Left
      color: "#4caf50"
    }
  }

  // ── fondo ──
  WidgetCard {
    anchors.fill: parent
    visible: w.showBg
    alpha: w.bgAlpha
    pill: w.sty === "capsule"
  }

  Item {
    id: ringS
    visible: w.sty === "ring"
    anchors.fill: parent
    readonly property real d: Math.max(40, w.u - 28)

    Ring {
      anchors.centerIn: parent
      width: ringS.d; height: ringS.d
      value: w.shownRemain
      tone: w.tone
      stroke: Math.max(5, Math.round(ringS.d * 0.06))
    }
    Text {
      x: (parent.width - width) / 2
      y: parent.height / 2 - ringS.d * 0.34
      width: ringS.d * 0.62
      horizontalAlignment: Text.AlignHCenter
      text: w.phaseLabel + (w.phase === "focus" ? "  " + w.roundStr : "")
      color: w.tone
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.max(9, Math.round(ringS.d * 0.065))
      fontSizeMode: Text.Fit; minimumPixelSize: 8; maximumLineCount: 1
    }
    Text {
      x: (parent.width - width) / 2
      y: parent.height / 2 - ringS.d * 0.21
      width: ringS.d * 0.66; height: ringS.d * 0.26
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: w.timeStr
      color: Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(ringS.d * 0.24)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
  }

  Column {
    visible: w.sty === "minimal"
    x: 18
    width: Math.max(20, w.ctlX - 18 - 8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    Text {
      width: parent.width
      text: w.phaseLabel + (w.phase === "focus" ? "  " + w.roundStr : "")
      color: w.tone
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      height: Math.max(20, Math.round(w.height * 0.5))
      verticalAlignment: Text.AlignVCenter
      text: w.timeStr
      color: Theme.text
      font.weight: Font.Light
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(w.height * 0.5)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
  }

  Item {
    visible: w.sty === "bar"
    anchors.fill: parent

    Text {
      x: 18; y: 12
      text: w.phaseLabel
      color: w.tone
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
    }
    Text {
      anchors { right: parent.right; rightMargin: 18 }
      y: 12
      text: w.roundStr
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
    }
    Text {
      x: 18
      y: (parent.height - height) / 2 - 4
      width: Math.max(20, w.ctlX - 18 - 8)
      height: Math.max(20, Math.round(w.height * 0.36))
      verticalAlignment: Text.AlignVCenter
      text: w.timeStr
      color: Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(w.height * 0.36)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
    Rectangle {
      x: 18; y: parent.height - 22
      width: Math.max(0, parent.width - 36); height: 8; radius: 4
      color: Qt.alpha(w.tone, 0.2)
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, w.shownRemain))
        height: parent.height; radius: 4
        color: w.tone
      }
    }
  }

  Item {
    id: dotsS
    visible: w.sty === "dots"
    anchors.fill: parent
    readonly property real dot: Math.max(7, Math.min(14, (w.width - 40) / (w.v.rounds * 1.9)))

    Text {
      x: (parent.width - width) / 2; y: 12
      width: parent.width - 32
      horizontalAlignment: Text.AlignHCenter
      text: w.phaseLabel
      color: w.tone
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
      elide: Text.ElideRight
    }
    Text {
      x: (parent.width - width) / 2; y: 30
      width: parent.width - 32
      height: Math.max(20, Math.round(w.height * 0.3))
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: w.timeStr
      color: Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(w.height * 0.3)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
    Row {
      x: (parent.width - width) / 2
      y: Math.max(40, w.ctlY - dotsS.dot - 14)
      spacing: Math.round(dotsS.dot * 0.9)
      Repeater {
        model: w.v.rounds
        delegate: Rectangle {
          required property int index
          readonly property bool done: index < w.doneCount
          readonly property bool current: w.phase === "focus" && index === w.v.round - 1
          width: dotsS.dot; height: dotsS.dot; radius: dotsS.dot / 2
          color: done ? w.tone : (current ? Qt.alpha(w.tone, 0.55) : Qt.alpha(Theme.subtext, 0.35))
          scale: current && w.v.running ? 1.18 : 1
          Behavior on scale { NumberAnimation { duration: 220 } }
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }
    }
  }

  Item {
    id: tm
    visible: w.sty === "tomato"
    anchors.fill: parent
    readonly property real ah: w.height - w.btnS - 24
    readonly property real d: Math.max(40, Math.min(w.width - 36, tm.ah - 14))
    readonly property real topY: 14 + (tm.ah - tm.d) / 2

    ClippingRectangle {
      x: (parent.width - tm.d) / 2; y: tm.topY
      width: tm.d; height: tm.d; radius: tm.d / 2
      color: Qt.alpha(w.tomatoTone, 0.2)
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * Math.max(0, Math.min(1, w.shownProg))
        color: w.tomatoTone
      }
    }
    Rectangle {
      width: tm.d * 0.06; height: tm.d * 0.13; radius: width / 2
      x: (parent.width - width) / 2; y: tm.topY - height * 0.5
      color: "#3f8f45"
    }
    Rectangle {
      width: tm.d * 0.27; height: tm.d * 0.1; radius: height / 2
      x: parent.width / 2 - width + tm.d * 0.02; y: tm.topY - tm.d * 0.01
      rotation: -16; transformOrigin: Item.Right
      color: "#4caf50"
    }
    Rectangle {
      width: tm.d * 0.27; height: tm.d * 0.1; radius: height / 2
      x: parent.width / 2 - tm.d * 0.02; y: tm.topY - tm.d * 0.01
      rotation: 16; transformOrigin: Item.Left
      color: "#4caf50"
    }
    Text {
      x: (parent.width - width) / 2; y: tm.topY + tm.d * 0.22
      width: tm.d * 0.7
      horizontalAlignment: Text.AlignHCenter
      text: w.phaseLabel + (w.phase === "focus" ? "  " + w.roundStr : "")
      color: w.shownProg > 0.78 ? "#ffffff" : w.tone
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.max(9, Math.round(tm.d * 0.07))
      fontSizeMode: Text.Fit; minimumPixelSize: 8; maximumLineCount: 1
    }
    Text {
      x: (parent.width - width) / 2; y: tm.topY + tm.d * 0.36
      width: tm.d * 0.7; height: tm.d * 0.26
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: w.timeStr
      color: w.shownProg > 0.55 ? "#ffffff" : Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(tm.d * 0.24)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
  }

  Item {
    id: cap
    visible: w.sty === "capsule"
    anchors.fill: parent
    readonly property real d: Math.max(30, w.height - 26)

    Ring {
      id: capRing
      x: Math.round((w.height - cap.d) / 2) + 4
      y: (cap.height - cap.d) / 2
      width: cap.d; height: cap.d
      value: w.shownRemain
      tone: w.tone
      stroke: Math.max(4, Math.round(cap.d * 0.09))
    }
    MiniTomato {
      anchors.centerIn: capRing
      width: Math.round(cap.d * 0.46); height: width
      tone: w.tomatoTone
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      x: capRing.x + capRing.width + 14
      width: Math.max(20, w.ctlX - (capRing.x + capRing.width + 14) - 8)
      spacing: 2
      Text {
        width: parent.width
        height: Math.max(20, Math.round(w.height * 0.36))
        verticalAlignment: Text.AlignVCenter
        text: w.timeStr
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(w.height * 0.36)
        fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
      }
      Row {
        spacing: 6
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 7; height: 7; radius: 3.5
          color: w.tone
          scale: w.v.running ? 1.25 : 1
          Behavior on scale { NumberAnimation { duration: 220 } }
        }
        Text {
          text: w.phaseLabel + (w.phase === "focus" ? "  " + w.roundStr : "")
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(11)
        }
      }
    }
  }

  Row {
    id: ctl
    x: w.ctlX
    y: w.ctlY
    spacing: w.gap
    CtlBtn {
      size: w.btnS; primary: true; tone: w.sty === "tomato" ? w.tomatoTone : w.tone
      icon: w.v.running ? "󰏤" : "󰐊"
      onClicked: PomodoroService.toggle(w.widgetId)
    }
    CtlBtn {
      size: w.btnS; icon: "󰒭"
      onClicked: PomodoroService.skip(w.widgetId)
    }
    CtlBtn {
      size: w.btnS; icon: "󰜉"
      onClicked: PomodoroService.reset(w.widgetId)
    }
  }
}
