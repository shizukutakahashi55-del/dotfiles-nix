// WeatherWidget — clima actual y pronóstico (Open-Meteo, sin API key; red con curl).

import QtQuick
import QtQuick.Layouts
import ".."
import "../../../COMMON"
import "../../../Services/Lang"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property bool pillStyle: w.sty === "compact" || w.sty === "minimal"
  readonly property real askPad: w.pillStyle ? Math.round(w.height * 0.3) : 14
  readonly property string city: String(w.opt("city", "")).trim()
  readonly property bool fahr: w.opt("fahrenheit", false)
  readonly property int refreshMin: Math.max(10, Math.round(Number(w.opt("refreshMin", 20))))
  readonly property bool showBg: w.opt("background", true)
  readonly property real bgAlpha: Math.max(0, Math.min(100, Number(w.opt("bgOpacity", 60)))) / 100
  readonly property var loc: Qt.locale(Translations.localeCode)

  // ── ciclo de vida ──
  property string _id: ""
  readonly property string sig: w.widgetId === "" ? "" : (w.widgetId + "|" + w.city + "|" + w.refreshMin)
  onSigChanged: {
    if (w.widgetId === "") return
    w._id = w.widgetId
    WeatherService.watch(w.widgetId, w.city, w.refreshMin)
  }
  Component.onDestruction: if (w._id !== "") WeatherService.unwatch(w._id)

  // ── datos ──
  readonly property bool noCity: w.city === ""
  readonly property var wx: w.noCity ? null : WeatherService.get(w.city)
  readonly property var cur: w.wx ? (w.wx.current ?? null) : null
  readonly property var daily: w.wx ? (w.wx.daily ?? []) : []
  readonly property var today: w.daily.length > 0 ? w.daily[0] : null
  readonly property bool cityIsCoords: /^\s*-?\d/.test(w.city)
  readonly property string placeShown: (w.wx && w.wx.name) ? w.wx.name
                                      : (w.city !== "" && !w.cityIsCoords ? w.city.split(",")[0].trim() : "")
  readonly property string regionShown: (w.wx && w.wx.region) ? w.wx.region : ""

  function tmp(c) { return Math.round(w.fahr ? c * 9 / 5 + 32 : c) + "°" }
  function windText(kmh) { return w.fahr ? Math.round(kmh / 1.609) + " mph" : Math.round(kmh) + " km/h" }
  function dayName(iso) {
    const t = w.loc.dayName(new Date(iso + "T12:00:00").getDay(), Locale.ShortFormat)
    return t.charAt(0).toUpperCase() + t.slice(1).replace(".", "")
  }


  readonly property color tint: {
    if (!w.cur) return "transparent"
    const g = WeatherService.group(w.cur.code), day = w.cur.isDay
    if (g === "clear" || g === "mostlyClear") return day ? "#ffb347" : "#5b6cff"
    if (g === "partly") return day ? "#7fb2e5" : "#4a5aa8"
    if (g === "rain" || g === "showers" || g === "drizzle") return "#4a90d9"
    if (g === "freezing" || g === "snow") return "#9fd0ff"
    if (g === "thunder") return "#9b59ff"
    return "#8a96ab"
  }

  // ── visibilidad: el widget aparece SOLO cuando ya hay datos del clima ──


  readonly property bool notFound: w.cur === null && !w.noCity && !!(w.wx && w.wx.error === "notfound")
  readonly property bool wxError: w.cur === null && !w.noCity && !w.notFound && !!(w.wx && w.wx.error)
  readonly property bool askCity: w.noCity || w.notFound
  readonly property bool shown: w.cur !== null || w.askCity || w.wxError || w.editMode
  opacity: w.shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280); easing.type: Easing.OutCubic } }

  // ── ciudad: edición desde el widget ──
  property bool cityEditing: false
  property bool pencilHover: false
  property bool warnEmpty: false
  property bool hadFocus: false

  readonly property Item inputArea: w.askCity ? emptyBox : (w.cityEditing ? editBox : pencil)
  readonly property bool wantsKeyboard: w.askCity || w.cityEditing || w.pencilHover

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

  // ── fondo + velo ──
  WidgetCard {
    id: bgCard
    anchors.fill: parent
    visible: w.showBg && w.shown
    alpha: w.bgAlpha
    pill: w.pillStyle
  }
  Rectangle {
    visible: w.showBg && !Theme.cozy && w.cur !== null
    anchors.fill: parent
    radius: bgCard.radius
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(w.tint.r, w.tint.g, w.tint.b, 0.26) }
      GradientStop { position: 0.75; color: Qt.rgba(w.tint.r, w.tint.g, w.tint.b, 0.04) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ── pedir ciudad (sin ciudad / no encontrada) ──


  Column {
    visible: w.cur === null && (w.askCity || w.wxError || w.editMode)
    anchors.centerIn: parent
    width: Math.max(40, w.width - 2 * w.askPad)
    spacing: 8

    Text {
      visible: w.askCity && w.height >= 170
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "󰖐"
      color: Theme.primary
      font.family: Theme.monoFamily
      font.pixelSize: Math.round(Math.min(40, Math.min(w.width, w.height) * 0.2))
    }
    Text {
      visible: w.height >= 80
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 1
      color: (w.warnEmpty || w.notFound || w.wxError) ? Theme.error : (w.askCity ? Theme.text : Theme.subtext)
      font.family: Theme.fontFamily
      font.bold: w.askCity
      font.pixelSize: Theme.fs(w.askCity ? 12 : 11)
      text: w.notFound ? Translations.t("wgWxNotFound")
          : w.noCity ? Translations.t("wgWxNoCity")
          : w.wxError ? Translations.t("wgWxError")
          : Translations.t("wgWxLoading")
    }

    CityBox {
      id: emptyBox
      visible: w.askCity
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, 300)
      onSubmitted: text => w.applyCity(text)
    }
    Text {
      visible: w.askCity && w.height >= 140
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 2
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(10)
      text: Translations.t("wgWxNoCityHint")
    }
  }

  // ── cambiar la ciudad (lápiz → input) ──
  Rectangle {
    id: pencil
    readonly property bool pillStyle: w.sty === "compact" || w.sty === "minimal"
    readonly property real capR: Math.min(bgCard.radius, w.height / 2)
    readonly property real corner: pencil.pillStyle
      ? Math.max(4, Math.round(pencil.capR - Math.max(0, pencil.capR - 17) * 0.7071 - 11)) : 6
    visible: !w.noCity && !w.cityEditing && !w.editMode
    z: 20
    width: 22; height: 22; radius: 11
    anchors { top: parent.top; right: parent.right; topMargin: pencil.corner; rightMargin: pencil.corner }
    opacity: pencilMa.containsMouse ? 1 : (w.sty === "minimal" ? 0 : 0.65)
    color: pencilMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                  : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.70)
    Text {
      anchors.centerIn: parent
      text: "󰏫"
      color: Theme.primary
      font.family: Theme.monoFamily
      font.pixelSize: 12
    }
    MouseArea {
      id: pencilMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: w.pencilHover = containsMouse
      onClicked: w.cityEditing = true
    }
  }
  CityBox {
    id: editBox
    visible: w.cityEditing && !w.noCity
    z: 21
    anchors { left: parent.left; right: parent.right; leftMargin: w.pillStyle ? w.askPad : 8; rightMargin: w.pillStyle ? w.askPad : 8 }
    y: w.pillStyle ? Math.round((w.height - height) / 2) : 8
    onSubmitted: text => w.applyCity(text)
    onCancelled: w.cityEditing = false
    onFocusLost: { if (w.cityEditing && w.hadFocus) w.cityEditing = false }
    onFocusGained: w.hadFocus = true
  }
  Text {
    visible: w.cityEditing && !w.noCity && w.warnEmpty
    z: 21
    anchors { left: editBox.left; right: editBox.right; top: editBox.bottom; topMargin: 3; leftMargin: 10 }
    elide: Text.ElideRight
    color: Theme.error
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fs(10)
    text: Translations.t("wgWxNoCity")
  }

  Row {
    id: cpRow
    visible: w.cur !== null && w.sty === "compact"
    anchors.centerIn: parent
    spacing: Math.round(w.height * 0.12)
    readonly property real iconS: Math.round(w.height * 0.66)

    WeatherIcon {
      anchors.verticalCenter: parent.verticalCenter
      width: cpRow.iconS; height: width
      code: w.cur ? w.cur.code : 0
      isDay: w.cur ? w.cur.isDay : true
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(Math.max(cpTemp.implicitWidth, cpPlace.implicitWidth),
                      Math.max(20, w.width - 2 * w.askPad - cpRow.iconS - cpRow.spacing))
      Text {
        id: cpTemp
        text: w.cur ? w.tmp(w.cur.temp) : ""
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(w.height * 0.38)
      }
      Text {
        id: cpPlace
        visible: w.placeShown !== ""
        width: parent.width
        elide: Text.ElideRight
        text: w.placeShown
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(9, Math.round(w.height * 0.14))
      }
    }
  }

  Row {
    visible: w.cur !== null && w.sty === "minimal"
    anchors.centerIn: parent
    spacing: Math.round(w.height * 0.14)

    WeatherIcon {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(w.height * 0.7); height: width
      code: w.cur ? w.cur.code : 0
      isDay: w.cur ? w.cur.isDay : true
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: w.cur ? w.tmp(w.cur.temp) : ""
      color: Theme.text
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(w.height * 0.46)
    }
  }

  Item {
    id: cardView
    visible: w.cur !== null && w.sty === "card"
    anchors { fill: parent; margins: 14 }

    WeatherIcon {
      id: cIcon
      anchors { left: parent.left; top: parent.top }
      width: Math.round(parent.height * 0.5); height: width
      code: w.cur ? w.cur.code : 0
      isDay: w.cur ? w.cur.isDay : true
    }
    Column {
      anchors { left: cIcon.right; leftMargin: 10; right: parent.right; rightMargin: 12; top: parent.top }
      Text {
        text: w.cur ? w.tmp(w.cur.temp) : ""
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(cardView.height * 0.3)
      }
      Text {
        width: parent.width
        elide: Text.ElideRight
        text: w.cur ? WeatherService.describe(w.cur.code) : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(12)
      }
      Text {
        width: parent.width
        elide: Text.ElideRight
        visible: w.placeShown !== ""
        text: w.placeShown + (w.regionShown !== "" ? " · " + w.regionShown : "")
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
      }
    }


    Row {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      spacing: 6
      Repeater {
        model: w.cur ? [
          { ic: "󰔏", tx: w.tmp(w.cur.feels) },
          { ic: "󰖎", tx: Math.round(w.cur.humidity) + "%" },
          { ic: "󰖝", tx: w.windText(w.cur.wind) }
        ] : []
        delegate: WidgetCard {
          required property var modelData
          tile: true
          width: (cardView.width - 12) / 3
          height: Math.max(26, Math.round(cardView.height * 0.26))
          Row {
            anchors.centerIn: parent
            spacing: 5
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.ic
              color: Theme.primary
              font.family: Theme.monoFamily
              font.pixelSize: Theme.fs(12)
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.tx
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fs(10)
            }
          }
        }
      }
    }
  }


  Item {
    id: fc
    visible: w.cur !== null && w.sty === "forecast"
    anchors { fill: parent; margins: 14 }
    clip: true

    readonly property int dayCount: Math.min(5, w.daily.length)
    readonly property bool roomy: width >= 360
    readonly property int iconSize: Math.max(40, Math.min(64, Math.round(width * 0.15)))

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      // ── arriba ──
      RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 16
        spacing: 10

        WeatherIcon {
          Layout.preferredWidth: fc.iconSize
          Layout.preferredHeight: fc.iconSize
          Layout.alignment: Qt.AlignVCenter
          code: w.cur ? w.cur.code : 0
          isDay: w.cur ? w.cur.isDay : true
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          Layout.alignment: Qt.AlignVCenter
          spacing: 0
          Text {
            text: w.cur ? w.tmp(w.cur.temp) : ""
            color: Theme.text; font.bold: true; font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(34)
          }
          Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: w.cur ? WeatherService.describe(w.cur.code) : ""
            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
          }
          Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            visible: w.placeShown !== ""
            text: w.placeShown + (w.regionShown !== "" ? " · " + w.regionShown : "")
            color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
          }
        }


        ColumnLayout {
          visible: fc.roomy
          Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
          spacing: 3
          Text {
            Layout.alignment: Qt.AlignRight
            visible: w.today !== null
            text: w.today ? "󰁝 " + w.tmp(w.today.max) + "   󰁅 " + w.tmp(w.today.min) : ""
            color: Theme.text; font.bold: true; font.family: Theme.monoFamily; font.pixelSize: Theme.fs(12)
          }
          Text {
            Layout.alignment: Qt.AlignRight
            text: w.cur ? Translations.t("wgWxFeels") + " " + w.tmp(w.cur.feels) : ""
            color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
          }
          Text {
            Layout.alignment: Qt.AlignRight
            text: w.cur ? "󰖎 " + Math.round(w.cur.humidity) + "%   󰖝 " + w.windText(w.cur.wind) : ""
            color: Theme.subtext; font.family: Theme.monoFamily; font.pixelSize: Theme.fs(10)
          }
          Text {
            Layout.alignment: Qt.AlignRight
            visible: w.cur !== null && w.cur.pressure !== undefined && w.cur.pressure !== null
            text: (w.cur && w.cur.pressure !== undefined && w.cur.pressure !== null) ? Math.round(w.cur.pressure) + " hPa" : ""
            color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
          }
          Text {
            Layout.alignment: Qt.AlignRight
            visible: w.today !== null && w.today.pop !== undefined && w.today.pop !== null
            text: w.today ? "󰖗 " + Math.round(w.today.pop || 0) + "%" : ""
            color: Theme.primary; font.family: Theme.monoFamily; font.pixelSize: Theme.fs(10)
          }
        }
      }

      // ── abajo: días ──
      RowLayout {
        id: fDays
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 64
        spacing: 6

        Repeater {
          model: fc.dayCount
          delegate: Rectangle {
            id: dayCell
            required property int index
            readonly property var d: w.daily[index]
            readonly property bool isToday: index === 0

            readonly property bool oneRow: (maxT.implicitWidth + minT.implicitWidth + 4) <= (dayCell.width - 12)

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            clip: true
            radius: Theme.cozy ? Theme.cardRadius : 12

            color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.38)
                           : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)

            ColumnLayout {
              anchors { fill: parent; margins: 6 }
              spacing: 2

              Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: dayCell.isToday ? Translations.t("wgWxToday") : w.dayName(dayCell.d.date)
                color: dayCell.isToday ? Theme.primary : Theme.subtext
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                font.bold: dayCell.isToday
              }
              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 14
                WeatherIcon {
                  anchors.centerIn: parent
                  width: Math.max(14, Math.min(parent.width, parent.height)); height: width
                  code: dayCell.d.code
                  isDay: true
                }
              }
              Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: dayCell.oneRow ? 2 : 1
                columnSpacing: 4
                horizontalItemAlignment: Grid.AlignHCenter
                Text {
                  id: maxT
                  text: w.tmp(dayCell.d.max)
                  color: Theme.text
                  font.bold: true; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                }
                Text {
                  id: minT
                  text: w.tmp(dayCell.d.min)
                  color: Theme.subtext
                  font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                }
              }
            }
          }
        }
      }
    }
  }
}
