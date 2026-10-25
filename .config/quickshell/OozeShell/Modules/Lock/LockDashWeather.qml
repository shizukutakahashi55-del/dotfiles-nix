// LockDashWeather

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../Widgets"

LockDashSection {
  id: root

  property bool active: true
  property string city: ""
  property bool fahrenheit: false
  property bool forecast: true
  property int days: 5

  // ── Datos ──
  readonly property var wx: root.city === "" ? null : WeatherService.get(root.city)
  readonly property var cur: root.wx ? (root.wx.current ?? null) : null
  readonly property var daily: root.wx ? (root.wx.daily ?? []) : []
  readonly property var today: root.daily.length > 0 ? root.daily[0] : null
  readonly property var dayList: root.daily.slice(0, Math.min(root.days, root.daily.length))
  readonly property bool ready: root.cur !== null
  readonly property bool cityIsCoords: /^\s*-?\d/.test(root.city)
  readonly property string place: (root.wx && root.wx.name) ? root.wx.name
                                  : (root.city !== "" && !root.cityIsCoords ? root.city.split(",")[0].trim() : "")
  readonly property string region: (root.wx && root.wx.region) ? root.wx.region : ""
  readonly property bool hasPressure: root.cur !== null && root.cur.pressure !== undefined && root.cur.pressure !== null
  readonly property bool hasPop: root.today !== null && root.today.pop !== undefined && root.today.pop !== null

  // ── Rango del pronóstico ──
  readonly property real lo: root.dayList.length > 0 ? Math.min.apply(null, root.dayList.map(d => d.min)) : 0
  readonly property real hi: root.dayList.length > 0 ? Math.max.apply(null, root.dayList.map(d => d.max)) : 1
  readonly property real span: Math.max(1, root.hi - root.lo)

  // ── Métricas ──
  readonly property var metrics: {
    if (!root.cur) return []
    const out = [
      { ic: 0xF058E, v: Math.round(root.cur.humidity) + "%", l: Translations.t("lockWxHumidity") },
      { ic: 0xF059D, v: root.windText(root.cur.wind), l: Translations.t("lockWxWind") }
    ]
    if (root.hasPressure) out.push({ ic: 0xF029A, v: Math.round(root.cur.pressure) + "", l: "hPa" })
    if (root.hasPop) out.push({ ic: 0xF0597, v: Math.round(root.today.pop || 0) + "%", l: Translations.t("lockWxRain") })
    return out
  }

  // ── Tinte ──
  readonly property color tint: {
    if (!root.cur) return "transparent"
    const g = WeatherService.group(root.cur.code), day = root.cur.isDay
    if (g === "clear" || g === "mostlyClear") return day ? "#ffb347" : "#5b6cff"
    if (g === "partly") return day ? "#7fb2e5" : "#4a5aa8"
    if (g === "rain" || g === "showers" || g === "drizzle") return "#4a90d9"
    if (g === "freezing" || g === "snow") return "#9fd0ff"
    if (g === "thunder") return "#9b59ff"
    return "#8a96ab"
  }

  // ── Formato ──
  function tmp(c) { return Math.round(root.fahrenheit ? c * 9 / 5 + 32 : c) + "°" }
  function windText(kmh) { return root.fahrenheit ? Math.round(kmh / 1.609) + " mph" : Math.round(kmh) + " km/h" }
  function glyph(cp) { return String.fromCodePoint(cp) }
  function dayName(iso) {
    const loc = Qt.locale(({ en: "en_US", es: "es_ES" })[Translations.current] || "en_US")
    const t = loc.dayName(new Date(iso + "T12:00:00").getDay(), Locale.ShortFormat)
    return t.charAt(0).toUpperCase() + t.slice(1).replace(".", "")
  }

  // ── Sección ──
  shown: root.active && root.ready
  icon: root.glyph(0xF0590)
  title: Translations.t("lockDashWeather")
  trailing: root.place + (root.place !== "" && root.region !== "" ? " · " + root.region : "")
  bodySpacing: Math.round(14 * root.unit)

  // ── Actual ──
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(12 * root.unit)

    WeatherIcon {
      Layout.preferredWidth: Math.round(58 * root.unit)
      Layout.preferredHeight: Math.round(58 * root.unit)
      Layout.alignment: Qt.AlignVCenter
      code: root.cur ? root.cur.code : 0
      isDay: root.cur ? root.cur.isDay : true
    }

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.cur ? root.tmp(root.cur.temp) : ""
      color: Theme.text
      font.pixelSize: Math.round(46 * root.unit)
      font.bold: true
      font.family: Theme.titleFamily
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(2 * root.unit)

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: root.cur ? WeatherService.describe(root.cur.code) : ""
        color: Theme.primary
        font.pixelSize: Math.round(13 * root.unit)
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        visible: root.today !== null
        horizontalAlignment: Text.AlignRight
        text: root.today ? root.glyph(0xF005D) + " " + root.tmp(root.today.max) + "   " + root.glyph(0xF0045) + " " + root.tmp(root.today.min) : ""
        color: Theme.text
        font.pixelSize: Math.round(12 * root.unit)
        font.bold: true
        font.family: Theme.monoFamily
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: root.cur ? Translations.t("lockWxFeels") + " " + root.tmp(root.cur.feels) : ""
        color: Theme.subtext
        font.pixelSize: Math.round(11 * root.unit)
        font.family: Theme.fontFamily
        elide: Text.ElideRight
      }
    }
  }

  // ── Métricas ──
  RowLayout {
    Layout.fillWidth: true
    spacing: 0

    Repeater {
      model: root.metrics

      delegate: RowLayout {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0

        Rectangle {
          visible: index > 0
          Layout.preferredWidth: 1
          Layout.preferredHeight: Math.round(34 * root.unit)
          Layout.alignment: Qt.AlignVCenter
          color: Theme.divider
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: Math.round(1 * root.unit)

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.glyph(modelData.ic)
            color: Theme.primary
            font.pixelSize: Math.round(15 * root.unit)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: modelData.v
            color: Theme.text
            font.pixelSize: Math.round(12 * root.unit)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: modelData.l
            color: Theme.subtext
            font.pixelSize: Math.round(10 * root.unit)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // ── Pronóstico ──
  ColumnLayout {
    visible: root.forecast && root.dayList.length > 0
    Layout.fillWidth: true
    spacing: Math.round(2 * root.unit)

    Repeater {
      model: root.forecast ? root.dayList.length : 0

      delegate: RowLayout {
        id: row
        required property int index
        readonly property var d: root.dayList[index]
        readonly property bool isToday: index === 0

        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(30 * root.unit)
        spacing: Math.round(8 * root.unit)

        Text {
          Layout.preferredWidth: Math.round(38 * root.unit)
          text: row.isToday ? Translations.t("wgWxToday") : root.dayName(row.d.date)
          color: row.isToday ? Theme.primary : Theme.subtext
          font.pixelSize: Math.round(12 * root.unit)
          font.bold: row.isToday
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }

        WeatherIcon {
          Layout.preferredWidth: Math.round(24 * root.unit)
          Layout.preferredHeight: Math.round(24 * root.unit)
          Layout.alignment: Qt.AlignVCenter
          code: row.d.code
          isDay: true
        }

        Text {
          Layout.preferredWidth: Math.round(32 * root.unit)
          horizontalAlignment: Text.AlignRight
          text: root.tmp(row.d.min)
          color: Theme.subtext
          font.pixelSize: Math.round(12 * root.unit)
          font.family: Theme.fontFamily
        }

        Item {
          id: bar
          Layout.fillWidth: true
          Layout.fillHeight: true

          readonly property real startX: (row.d.min - root.lo) / root.span * bar.width
          readonly property real fillW: Math.min(bar.width - bar.startX,
                                                 Math.max(Math.round(8 * root.unit), (row.d.max - row.d.min) / root.span * bar.width))

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.round(5 * root.unit)
            radius: Theme.cozy ? 0 : height / 2
            color: Theme.tint(0.12)
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(bar.startX)
            width: Math.round(bar.fillW)
            height: Math.round(5 * root.unit)
            radius: Theme.cozy ? 0 : height / 2
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "#7fb2e5" }
              GradientStop { position: 1.0; color: "#ffb347" }
            }
          }
          Rectangle {
            visible: row.isToday && root.cur !== null
            readonly property real at: root.cur ? Math.max(0, Math.min(1, (root.cur.temp - root.lo) / root.span)) : 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(9 * root.unit)
            height: width
            x: Math.round(at * bar.width - width / 2)
            radius: Theme.cozy ? 0 : width / 2
            color: Theme.text
            border.width: Math.max(1, Math.round(2 * root.unit))
            border.color: Qt.rgba(0, 0, 0, 0.45)
          }
        }

        Text {
          Layout.preferredWidth: Math.round(32 * root.unit)
          text: root.tmp(row.d.max)
          color: Theme.text
          font.pixelSize: Math.round(12 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
        }
      }
    }
  }
}
