// ClockWidget — estilos: digital · minimal · analog · hybrid · vertical

import Quickshell
import QtQuick
import ".."
import "../../COMMON"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property bool analog: w.sty === "analog"
  readonly property bool hybrid: w.sty === "hybrid"
  readonly property bool vertical: w.sty === "vertical"
  readonly property bool h24: w.opt("hour24", true)

  readonly property bool showSeconds: w.opt("seconds", false) || w.analog
  readonly property bool showDate: w.opt("date", true)
  readonly property bool showBg: w.opt("background", true)
  readonly property real bgAlpha: Math.max(0, Math.min(100, Number(w.opt("bgOpacity", 60)))) / 100

  SystemClock {
    id: clock
    precision: w.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }


  readonly property string mainStr: Qt.formatTime(clock.date, w.h24 ? "HH:mm" : "h:mm")
  readonly property string secStr: (w.showSeconds && !w.analog) ? ":" + Qt.formatTime(clock.date, "ss") : ""
  readonly property string apStr: w.h24 ? "" : Qt.formatTime(clock.date, "AP")
  readonly property string suffixStr: (w.secStr + (w.apStr !== "" ? (w.secStr !== "" ? " " : "") + w.apStr : ""))
  readonly property string dateText: Qt.formatDate(clock.date, "dddd, d MMMM")

  // ── TimeText: hora grande + sufijo pequeño sobre la misma línea base ──


  component TimeText: Item {
    id: tt
    property string main: ""
    property string suffix: ""
    property real availW: 100
    property real maxH: 60
    property int weight: Font.Bold
    property color tone: Theme.text
    property real ratio: 0.42

    readonly property string mainRef: tt.main.replace(/\d/g, "8")
    readonly property string sufRef: tt.suffix.replace(/\d/g, "8").replace(/[AaPp][Mm]/, "MM")
    TextMetrics { id: mm; font.family: Theme.fontFamily; font.weight: tt.weight; font.pixelSize: 100; text: tt.mainRef }
    TextMetrics { id: ms; font.family: Theme.fontFamily; font.weight: tt.weight; font.pixelSize: Math.round(100 * tt.ratio); text: tt.sufRef }

    readonly property real gap: tt.suffix !== "" ? 3 : 0
    readonly property real units: Math.max(1, (mm.advanceWidth + (tt.suffix !== "" ? ms.advanceWidth : 0)) / 100)
    readonly property real px: Math.max(10, Math.min(tt.maxH, (tt.availW - tt.gap) * 0.97 / tt.units))

    implicitWidth: Math.round(tt.units * tt.px + tt.gap)
    implicitHeight: mainT.implicitHeight

    Text {
      id: mainT
      text: tt.main
      color: tt.tone
      font.family: Theme.fontFamily
      font.weight: tt.weight
      font.pixelSize: Math.round(tt.px)
    }
    Text {
      visible: tt.suffix !== ""
      anchors { left: mainT.right; leftMargin: tt.gap; baseline: mainT.baseline }
      text: tt.suffix
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.weight: tt.weight === Font.Light ? Font.Normal : Font.DemiBold
      font.pixelSize: Math.max(8, Math.round(tt.px * tt.ratio))
    }
  }

  // ── Hand: manecilla = Item del tamaño del reloj que gira sobre su centro ──
  component Hand: Item {
    property real size: 100
    property real angle: 0
    property real length: 0.3
    property real thick: 3
    property color tone: Theme.text
    anchors.fill: parent
    rotation: angle
    Rectangle {
      width: parent.thick
      height: parent.size * parent.length
      x: (parent.size - width) / 2
      y: parent.size / 2 - height
      radius: width / 2
      color: parent.tone
    }
  }

  // ── AnalogFace: esfera reutilizada por «analog» y «hybrid» ──
  component AnalogFace: Item {
    id: af
    property var clk: null
    property bool disc: true
    property bool secHand: true
    property bool dateInside: false
    property real alpha: 0.6
    readonly property real s: Math.min(width, height)


    WidgetBlur {
      allowed: af.disc
      anchors.centerIn: parent
      width: af.s; height: af.s
      radius: width / 2
    }
    Rectangle {
      anchors.centerIn: parent
      width: af.s; height: af.s
      radius: width / 2
      color: af.disc ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, af.alpha) : "transparent"
      border.color: Theme.text
      border.width: af.disc ? 0 : 2
    }
    Item {
      anchors.centerIn: parent
      width: af.s; height: af.s


      Repeater {
        model: 12
        delegate: Item {
          required property int index
          anchors.fill: parent
          rotation: index * 30
          Rectangle {
            width: index % 3 === 0 ? 3 : 2
            height: index % 3 === 0 ? af.s * 0.07 : af.s * 0.04
            x: (af.s - width) / 2
            y: af.s * 0.05
            radius: 1
            color: index % 3 === 0 ? Theme.text : Theme.subtext
          }
        }
      }

      Hand { size: af.s; angle: af.clk ? ((af.clk.hours % 12) + af.clk.minutes / 60) * 30 : 0; length: 0.26; thick: 4 }
      Hand { size: af.s; angle: af.clk ? (af.clk.minutes + af.clk.seconds / 60) * 6 : 0; length: 0.38; thick: 3 }
      Hand { visible: af.secHand; size: af.s; angle: af.clk ? af.clk.seconds * 6 : 0; length: 0.42; thick: 1.5; tone: Theme.primary }

      Rectangle {
        anchors.centerIn: parent
        width: 8; height: 8; radius: 4
        color: Theme.primary
      }

      Text {
        visible: af.dateInside
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: af.s * 0.2 }
        text: af.clk ? Qt.formatDate(af.clk.date, "d MMM") : ""
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(7, Math.round(af.s * 0.07))
      }
    }
  }

  // ── fondo (todos menos analog, que lleva su propio disco) ──
  WidgetCard {
    visible: w.showBg && !w.analog
    anchors.fill: parent
    alpha: w.bgAlpha
  }

  // ═════════ digital / minimal ═════════
  Column {
    visible: w.sty === "digital" || w.sty === "minimal"
    anchors.centerIn: parent
    width: Math.max(10, w.width - 28)
    spacing: 2
    Item {
      width: parent.width
      height: dgTime.implicitHeight
      TimeText {
        id: dgTime
        anchors.horizontalCenter: parent.horizontalCenter
        main: w.mainStr
        suffix: w.suffixStr
        availW: w.width - 28
        maxH: Math.max(12, Math.round(w.height * (w.sty === "minimal" ? 0.62 : 0.5)))
        weight: w.sty === "minimal" ? Font.Light : Font.Bold
      }
    }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width * 0.4, 120)
      height: 3
      radius: 1.5
      color: Theme.primary
      opacity: 0.55
    }
    Item {
      visible: w.showDate && w.sty === "digital"
      width: parent.width
      height: dgDate.implicitHeight
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: OozeIcons.calendar
          color: Theme.primary
          font.family: Theme.monoFamily
          font.pixelSize: Math.max(8, Math.round(w.height * 0.14))
        }
        Text {
          id: dgDate
          anchors.verticalCenter: parent.verticalCenter
          text: w.dateText
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Math.max(8, Math.round(w.height * 0.16))
        }
      }
    }
  }

  // ═════════ analog ═════════
  AnalogFace {
    visible: w.analog
    anchors.centerIn: parent
    width: Math.min(w.width, w.height); height: width
    clk: clock
    disc: w.showBg
    alpha: w.bgAlpha
    secHand: true
    dateInside: w.showDate
  }

  // ═════════ hybrid ═════════


  Item {
    id: hy
    visible: w.hybrid
    anchors { fill: parent; margins: 14 }
    readonly property real faceS: Math.min(hy.height, Math.round(hy.width * 0.46))

    AnalogFace {
      id: hyFace
      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
      width: hy.faceS; height: hy.faceS
      clk: clock
      disc: false
      secHand: w.showSeconds
      alpha: w.bgAlpha
    }
    Column {
      anchors { left: hyFace.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: 2
      TimeText {
        main: w.mainStr
        suffix: w.suffixStr
        availW: hy.width - hy.faceS - 16
        maxH: Math.max(14, Math.round(hy.height * 0.46))
        weight: Font.Light
      }
      Text {
        visible: w.showDate
        width: parent.width
        elide: Text.ElideRight
        text: Qt.formatDate(clock.date, "d MMMM")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(Math.max(10, Math.round(hy.height * 0.12)))
      }
      Text {
        visible: w.showDate
        width: parent.width
        elide: Text.ElideRight
        text: { const t = Qt.formatDate(clock.date, "dddd"); return t.charAt(0).toUpperCase() + t.slice(1) }
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(Math.max(10, Math.round(hy.height * 0.11)))
      }
    }
  }

  // ═════════ vertical ═════════


  Column {
    id: vt
    visible: w.vertical
    anchors { fill: parent; margins: 12 }
    spacing: 0
    readonly property real avail: vt.height - (w.suffixStr !== "" ? 22 : 0) - (w.showDate ? 20 : 0)
    readonly property real lineH: Math.max(20, vt.avail / 2)

    Text {
      width: parent.width; height: vt.lineH
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: Qt.formatTime(clock.date, w.h24 ? "HH" : "h")
      color: Theme.primary
      font.family: Theme.fontFamily; font.weight: Font.Black; font.bold: true
      font.pixelSize: Math.round(vt.lineH)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
    Text {
      width: parent.width; height: vt.lineH
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: ":" + Qt.formatTime(clock.date, "mm")
      color: Theme.primary
      font.family: Theme.fontFamily; font.weight: Font.Black; font.bold: true
      font.pixelSize: Math.round(vt.lineH)
      fontSizeMode: Text.Fit; minimumPixelSize: 10; maximumLineCount: 1
    }
    Text {
      visible: w.suffixStr !== ""
      width: parent.width; height: 22
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: w.suffixStr
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(12)
      fontSizeMode: Text.Fit; minimumPixelSize: 8; maximumLineCount: 1
    }
    Text {
      visible: w.showDate
      width: parent.width; height: 20
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      text: Qt.formatDate(clock.date, "ddd d MMM")
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(10)
      fontSizeMode: Text.Fit; minimumPixelSize: 7; maximumLineCount: 1
    }
  }
}
