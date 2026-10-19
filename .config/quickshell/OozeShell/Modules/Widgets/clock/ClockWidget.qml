// ClockWidget — estilos: digital · minimal · analog · hybrid · vertical · weather · weathermini

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../COMMON"
import "../../../Services/Lang"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property bool analog: w.sty === "analog"
  readonly property bool hybrid: w.sty === "hybrid"
  readonly property bool vertical: w.sty === "vertical"
  readonly property bool h24: w.opt("hour24", true)
  readonly property var loc: Qt.locale(Translations.localeCode)

  readonly property bool showSeconds: w.opt("seconds", false) || w.analog
  readonly property bool showDate: w.opt("date", true)
  readonly property bool showBg: w.opt("background", true)
  readonly property real bgAlpha: Math.max(0, Math.min(100, Number(w.opt("bgOpacity", 60)))) / 100

  // ── clima ──
  readonly property bool wxStyle: w.sty === "weather" || w.sty === "weathermini"
  readonly property bool mini: w.sty === "weathermini"
  readonly property string city: String(w.opt("city", "")).trim()
  readonly property bool fahr: w.opt("fahrenheit", false)
  readonly property int refreshMin: Math.max(10, Math.round(Number(w.opt("refreshMin", 20))))

  property string _id: ""
  readonly property string sig: (w.wxStyle && w.widgetId !== "") ? (w.widgetId + "|" + w.city + "|" + w.refreshMin) : ""
  onSigChanged: {
    if (w.sig === "") {
      if (w._id !== "") { WeatherService.unwatch(w._id); w._id = "" }
      return
    }
    w._id = w.widgetId
    WeatherService.watch(w.widgetId, w.city, w.refreshMin)
  }
  Component.onDestruction: if (w._id !== "") WeatherService.unwatch(w._id)

  readonly property bool noCity: w.city === ""
  readonly property var wx: (w.wxStyle && !w.noCity) ? WeatherService.get(w.city) : null
  readonly property var cur: w.wx ? (w.wx.current ?? null) : null
  readonly property bool notFound: w.cur === null && !w.noCity && !!(w.wx && w.wx.error === "notfound")
  readonly property bool askCity: w.noCity || w.notFound

  function tmp(c) { return Math.round(w.fahr ? c * 9 / 5 + 32 : c) + "°" }

  property bool cityEditing: false
  property bool paneHover: false
  property bool warnEmpty: false
  property bool hadFocus: false

  readonly property Item inputArea: w.wxStyle ? (w.cityEditing ? editBox : wxPane) : null
  readonly property bool wantsKeyboard: w.wxStyle && (w.cityEditing || w.paneHover)

  function applyCity(t) {
    const v = String(t || "").trim()
    if (v === "") { w.warnEmpty = true; warnTimer.restart(); return }
    w.warnEmpty = false
    WidgetConfig.setOption(w.widgetId, "city", v)
    w.cityEditing = false
  }
  Timer { id: warnTimer; interval: 3500; onTriggered: w.warnEmpty = false }
  onCityEditingChanged: {
    w.warnEmpty = false
    if (w.cityEditing) {
      w.hadFocus = false
      editBox.field.text = w.city
      editBox.field.forceActiveFocus()
      editBox.field.selectAll()
    } else {
      editBox.field.focus = false
    }
  }

  SystemClock {
    id: clock
    precision: w.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }


  readonly property string mainStr: Qt.formatTime(clock.date, w.h24 ? "HH:mm" : "h:mm")
  readonly property string secStr: (w.showSeconds && !w.analog) ? ":" + Qt.formatTime(clock.date, "ss") : ""
  readonly property string apStr: w.h24 ? "" : Qt.formatTime(clock.date, "AP")
  readonly property string suffixStr: (w.secStr + (w.apStr !== "" ? (w.secStr !== "" ? " " : "") + w.apStr : ""))
  readonly property string dateText: w.loc.toString(clock.date, "dddd, d MMMM")

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
    property bool ring: false
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
      border.color: (af.disc && af.ring) ? Qt.alpha(Theme.primary, 0.85) : Theme.text
      border.width: af.disc ? (af.ring ? 2 : 0) : 2
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
        text: af.clk ? w.loc.toString(af.clk.date, "d MMM") : ""
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
    pill: w.mini
  }

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

  AnalogFace {
    visible: w.analog
    anchors.centerIn: parent
    width: Math.min(w.width, w.height); height: width
    clk: clock
    disc: w.showBg
    ring: w.showBorder
    alpha: w.bgAlpha
    secHand: true
    dateInside: w.showDate
  }


  Item {
    id: hy
    visible: w.hybrid
    anchors { fill: parent; margins: 14 }
    readonly property real faceS: Math.min(hy.height, Math.round(hy.width * 0.46))
    readonly property real gap: 18
    readonly property real textMax: Math.max(20, hy.width - hy.faceS - hy.gap)

    Row {
      anchors.centerIn: parent
      spacing: hy.gap

      AnalogFace {
        id: hyFace
        anchors.verticalCenter: parent.verticalCenter
        width: hy.faceS; height: hy.faceS
        clk: clock
        disc: false
        secHand: w.showSeconds
        alpha: w.bgAlpha
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(hy.textMax, Math.max(hyTime.implicitWidth,
                                             w.showDate ? hyDay.implicitWidth : 0,
                                             w.showDate ? hyWeek.implicitWidth : 0))
        spacing: 2
        TimeText {
          id: hyTime
          main: w.mainStr
          suffix: w.suffixStr
          availW: hy.textMax
          maxH: Math.max(14, Math.round(hy.height * 0.46))
          weight: Font.Light
        }
        Text {
          id: hyDay
          visible: w.showDate
          width: parent.width
          elide: Text.ElideRight
          text: w.loc.toString(clock.date, "d MMMM")
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(Math.max(10, Math.round(hy.height * 0.12)))
        }
        Text {
          id: hyWeek
          visible: w.showDate
          width: parent.width
          elide: Text.ElideRight
          text: { const t = w.loc.toString(clock.date, "dddd"); return t.charAt(0).toUpperCase() + t.slice(1) }
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(Math.max(10, Math.round(hy.height * 0.11)))
        }
      }
    }
  }


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
      text: w.loc.toString(clock.date, "ddd d MMM")
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(10)
      fontSizeMode: Text.Fit; minimumPixelSize: 7; maximumLineCount: 1
    }
  }

  Item {
    id: wxv
    visible: w.wxStyle
    anchors {
      fill: parent
      margins: w.mini ? 12 : 14
      leftMargin: w.mini ? 22 : 14
      rightMargin: w.mini ? 22 : 14
    }
    opacity: w.cityEditing ? 0.2 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }
    readonly property real paneW: Math.round(wxv.width * (w.mini ? 0.32 : 0.34))

    Row {
      id: wxRow
      anchors.centerIn: parent
      height: parent.height
      spacing: 14
      readonly property real leftMax: Math.max(20, wxv.width - wxv.paneW - 2 * wxRow.spacing - 1)

      Column {
        id: wxLeft
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(wxRow.leftMax, Math.max(wxTime.implicitWidth,
                                                wxDateA.visible ? wxDateA.implicitWidth : 0,
                                                wxDateB.visible ? wxDateB.implicitWidth : 0))
        spacing: 2
        TimeText {
          id: wxTime
          main: w.mainStr
          suffix: w.suffixStr
          availW: wxRow.leftMax
          maxH: Math.max(14, Math.round(wxv.height * (w.mini ? 0.72 : 0.5)))
          weight: Font.DemiBold
        }
        Text {
          id: wxDateA
          visible: w.showDate && !w.mini
          width: parent.width
          elide: Text.ElideRight
          text: w.loc.toString(clock.date, "d MMM yyyy")
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(Math.max(10, Math.round(wxv.height * 0.12)))
        }
        Text {
          id: wxDateB
          visible: w.showDate && !w.mini
          width: parent.width
          elide: Text.ElideRight
          text: { const t = w.loc.toString(clock.date, "dddd"); return t.charAt(0).toUpperCase() + t.slice(1) }
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fs(Math.max(10, Math.round(wxv.height * 0.12)))
        }
      }

      Rectangle {
        id: wxDiv
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 8
        width: 1
        color: Theme.divider
      }

      Item {
        id: wxPane
        width: wxv.paneW
        height: parent.height

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: w.paneHover = containsMouse
          onClicked: w.cityEditing = true
        }
        ColumnLayout {
          id: wxCol
          anchors.centerIn: parent
          width: parent.width
          spacing: 2
          readonly property real ic: Math.round(Math.min(wxPane.width * 0.62, wxPane.height * (w.mini ? 0.5 : 0.46)))

          WeatherIcon {
            visible: w.cur !== null
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: wxCol.ic
            Layout.preferredHeight: wxCol.ic
            code: w.cur ? w.cur.code : 0
            isDay: w.cur ? w.cur.isDay : true
          }
          Text {
            visible: w.cur !== null
            Layout.alignment: Qt.AlignHCenter
            text: w.cur ? w.tmp(w.cur.temp) : ""
            color: Theme.text
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(wxv.height * (w.mini ? 0.32 : 0.2))
          }
          Text {
            visible: w.cur === null
            Layout.alignment: Qt.AlignHCenter
            text: "󰖐"
            color: Theme.primary
            font.family: Theme.monoFamily
            font.pixelSize: Math.round(Math.min(wxPane.width * 0.4, wxv.height * 0.34))
          }
          Text {
            visible: w.cur === null
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: w.askCity ? Translations.t("wgWxSetCity") : Translations.t("wgWxLoading")
            color: w.notFound ? Theme.error : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
          }
        }
      }
    }
  }

  CityBox {
    id: editBox
    visible: w.cityEditing && w.wxStyle
    z: 21
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
    onSubmitted: text => w.applyCity(text)
    onCancelled: w.cityEditing = false
    onFocusLost: { if (w.cityEditing && w.hadFocus) w.cityEditing = false }
    onFocusGained: w.hadFocus = true
  }
  Text {
    visible: w.cityEditing && w.wxStyle && w.warnEmpty
    z: 21
    anchors { left: editBox.left; right: editBox.right; top: editBox.bottom; topMargin: 3; leftMargin: 10 }
    elide: Text.ElideRight
    color: Theme.error
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fs(10)
    text: Translations.t("wgWxNoCity")
  }
}
