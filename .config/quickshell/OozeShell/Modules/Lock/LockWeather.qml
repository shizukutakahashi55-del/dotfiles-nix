// LockWeather

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Lang"
import "../Widgets"

SkinRect {
  id: root

  property real unit: 1
  property bool active: true
  property string city: ""
  property bool fahrenheit: false
  property bool forecast: true
  property string look: "forecast"
  property int days: 5
  property bool tintOn: true
  property bool vertical: false
  property int cardWidth: 0

  // ── Datos ──
  readonly property var wx: root.city === "" ? null : WeatherService.get(root.city)
  readonly property var cur: root.wx ? (root.wx.current ?? null) : null
  readonly property var daily: root.wx ? (root.wx.daily ?? []) : []
  readonly property var today: root.daily.length > 0 ? root.daily[0] : null
  readonly property bool ready: root.cur !== null
  readonly property var upcoming: root.daily.slice(1, 4)
  readonly property var dayList: root.daily.slice(0, Math.min(root.days, root.daily.length))
  readonly property bool cityIsCoords: /^\s*-?\d/.test(root.city)
  readonly property string place: (root.wx && root.wx.name) ? root.wx.name
                                  : (root.city !== "" && !root.cityIsCoords ? root.city.split(",")[0].trim() : "")
  readonly property string region: (root.wx && root.wx.region) ? root.wx.region : ""
  readonly property string placeLine: root.place + (root.place !== "" && root.region !== "" ? " · " + root.region : "")
  readonly property bool hasPressure: root.cur !== null && root.cur.pressure !== undefined && root.cur.pressure !== null
  readonly property bool hasPop: root.today !== null && root.today.pop !== undefined && root.today.pop !== null

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

  // ── Geometría ──
  readonly property bool modern: root.look !== "classic"
  readonly property int pad: Math.round((root.modern ? 16 : 18) * root.unit)
  readonly property int wide: root.cardWidth > 0 ? root.cardWidth : Math.round(480 * root.unit)
  readonly property bool roomy: root.wide >= Math.round(420 * root.unit)

  implicitWidth: root.modern ? root.wide
               : (root.vertical && root.cardWidth > 0 ? root.cardWidth : body.implicitWidth + root.pad * 2)
  implicitHeight: (root.look === "forecast" ? fc.implicitHeight
                 : root.look === "card" ? cd.implicitHeight
                 : body.implicitHeight) + root.pad * 2

  radius: Theme.cardRadius
  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.14)

  visible: opacity > 0
  opacity: root.active && root.ready ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration(280); easing.type: Easing.OutCubic } }

  // ── Velo de color ──
  Rectangle {
    anchors.fill: parent
    visible: root.tintOn && root.modern && !Theme.cozy && root.ready
    radius: root.radius
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.26) }
      GradientStop { position: 0.75; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.04) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ── Forecast ──
  ColumnLayout {
    id: fc
    visible: root.look === "forecast"
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
    spacing: Math.round(10 * root.unit)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(12 * root.unit)

      WeatherIcon {
        Layout.preferredWidth: Math.round(60 * root.unit)
        Layout.preferredHeight: Math.round(60 * root.unit)
        Layout.alignment: Qt.AlignVCenter
        code: root.cur ? root.cur.code : 0
        isDay: root.cur ? root.cur.isDay : true
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        Text {
          text: root.cur ? root.tmp(root.cur.temp) : ""
          color: Theme.text
          font.pixelSize: Math.round(40 * root.unit)
          font.bold: true
          font.family: Theme.titleFamily
        }
        Text {
          Layout.fillWidth: true
          text: root.cur ? WeatherService.describe(root.cur.code) : ""
          color: Theme.primary
          font.pixelSize: Math.round(13 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: root.placeLine !== ""
          text: root.placeLine
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
      }

      ColumnLayout {
        visible: root.roomy
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        spacing: Math.round(3 * root.unit)

        Text {
          Layout.alignment: Qt.AlignRight
          visible: root.today !== null
          text: root.today ? "󰁝 " + root.tmp(root.today.max) + "   󰁅 " + root.tmp(root.today.min) : ""
          color: Theme.text
          font.pixelSize: Math.round(13 * root.unit)
          font.bold: true
          font.family: Theme.monoFamily
        }
        Text {
          Layout.alignment: Qt.AlignRight
          text: root.cur ? Translations.t("lockWxFeels") + " " + root.tmp(root.cur.feels) : ""
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.alignment: Qt.AlignRight
          text: root.cur ? "󰖎 " + Math.round(root.cur.humidity) + "%   󰖝 " + root.windText(root.cur.wind) : ""
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.monoFamily
        }
        Text {
          Layout.alignment: Qt.AlignRight
          visible: root.hasPressure
          text: root.hasPressure ? Math.round(root.cur.pressure) + " hPa" : ""
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
        }
        Text {
          Layout.alignment: Qt.AlignRight
          visible: root.hasPop
          text: root.hasPop ? "󰖗 " + Math.round(root.today.pop || 0) + "%" : ""
          color: Theme.primary
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.monoFamily
        }
      }
    }

    // ── Días ──
    RowLayout {
      visible: root.forecast && root.dayList.length > 0
      Layout.fillWidth: true
      spacing: Math.round(6 * root.unit)

      Repeater {
        model: root.forecast ? root.dayList.length : 0

        delegate: Rectangle {
          id: dayCell
          required property int index
          readonly property var d: root.dayList[index]
          readonly property bool isToday: index === 0
          readonly property bool oneRow: (maxT.implicitWidth + minT.implicitWidth + 4) <= (dayCell.width - Math.round(12 * root.unit))

          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.preferredHeight: Math.round(102 * root.unit)
          clip: true
          radius: Theme.cozy ? Theme.cardRadius : Math.round(12 * root.unit)
          color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.38)
                         : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)

          ColumnLayout {
            anchors { fill: parent; margins: Math.round(6 * root.unit) }
            spacing: Math.round(2 * root.unit)

            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: dayCell.isToday ? Translations.t("wgWxToday") : root.dayName(dayCell.d.date)
              color: dayCell.isToday ? Theme.primary : Theme.subtext
              font.pixelSize: Math.round(11 * root.unit)
              font.bold: dayCell.isToday
              font.family: Theme.fontFamily
            }
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: Math.round(14 * root.unit)

              WeatherIcon {
                anchors.centerIn: parent
                width: Math.max(14, Math.min(parent.width, parent.height))
                height: width
                code: dayCell.d.code
                isDay: true
              }
            }
            Grid {
              Layout.alignment: Qt.AlignHCenter
              columns: dayCell.oneRow ? 2 : 1
              columnSpacing: Math.round(4 * root.unit)
              horizontalItemAlignment: Grid.AlignHCenter

              Text {
                id: maxT
                text: root.tmp(dayCell.d.max)
                color: Theme.text
                font.pixelSize: Math.round(12 * root.unit)
                font.bold: true
                font.family: Theme.fontFamily
              }
              Text {
                id: minT
                text: root.tmp(dayCell.d.min)
                color: Theme.subtext
                font.pixelSize: Math.round(12 * root.unit)
                font.family: Theme.fontFamily
              }
            }
          }
        }
      }
    }
  }

  // ── Tarjeta ──
  ColumnLayout {
    id: cd
    visible: root.look === "card"
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
    spacing: Math.round(12 * root.unit)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(14 * root.unit)

      WeatherIcon {
        Layout.preferredWidth: Math.round(68 * root.unit)
        Layout.preferredHeight: Math.round(68 * root.unit)
        Layout.alignment: Qt.AlignVCenter
        code: root.cur ? root.cur.code : 0
        isDay: root.cur ? root.cur.isDay : true
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        Text {
          text: root.cur ? root.tmp(root.cur.temp) : ""
          color: Theme.text
          font.pixelSize: Math.round(42 * root.unit)
          font.bold: true
          font.family: Theme.titleFamily
        }
        Text {
          Layout.fillWidth: true
          text: root.cur ? WeatherService.describe(root.cur.code) : ""
          color: Theme.text
          font.pixelSize: Math.round(13 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: root.placeLine !== ""
          text: root.placeLine
          color: Theme.subtext
          font.pixelSize: Math.round(11 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(6 * root.unit)

      Repeater {
        model: root.cur ? [
          { ic: "󰔏", tx: root.tmp(root.cur.feels) },
          { ic: "󰖎", tx: Math.round(root.cur.humidity) + "%" },
          { ic: "󰖝", tx: root.windText(root.cur.wind) }
        ] : []

        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.preferredHeight: Math.round(36 * root.unit)
          radius: Theme.cozy ? Theme.cardRadius : Math.round(10 * root.unit)
          color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)

          Row {
            anchors.centerIn: parent
            spacing: Math.round(6 * root.unit)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.ic
              color: Theme.primary
              font.pixelSize: Math.round(14 * root.unit)
              font.family: Theme.monoFamily
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.tx
              color: Theme.text
              font.pixelSize: Math.round(12 * root.unit)
              font.family: Theme.fontFamily
            }
          }
        }
      }
    }
  }

  // ── Clásico ──
  GridLayout {
    id: body
    visible: root.look === "classic"
    anchors { left: parent.left; top: parent.top; margins: root.pad }
    width: root.vertical ? parent.width - root.pad * 2 : implicitWidth
    columns: root.vertical ? 1 : 5
    columnSpacing: Math.round(16 * root.unit)
    rowSpacing: Math.round(14 * root.unit)

    // ── Actual ──
    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(16 * root.unit)

      WeatherIcon {
        Layout.preferredWidth: Math.round(64 * root.unit)
        Layout.preferredHeight: Math.round(64 * root.unit)
        Layout.alignment: Qt.AlignVCenter
        code: root.cur ? root.cur.code : 0
        isDay: root.cur ? root.cur.isDay : true
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        Text {
          text: root.cur ? root.tmp(root.cur.temp) : ""
          color: Theme.text
          font.pixelSize: Math.round(40 * root.unit)
          font.bold: true
          font.family: Theme.titleFamily
        }
        Text {
          Layout.fillWidth: true
          text: root.cur ? WeatherService.describe(root.cur.code) : ""
          color: Theme.primary
          font.pixelSize: Math.round(14 * root.unit)
          font.bold: true
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: root.place !== ""
          text: root.place
          color: Theme.subtext
          font.pixelSize: Math.round(12 * root.unit)
          font.family: Theme.fontFamily
          elide: Text.ElideRight
        }
      }
    }

    Rectangle {
      Layout.fillWidth: root.vertical
      Layout.preferredWidth: root.vertical ? -1 : 1
      Layout.preferredHeight: root.vertical ? 1 : Math.round(58 * root.unit)
      Layout.alignment: Qt.AlignVCenter
      color: Theme.divider
    }

    // ── Detalles ──
    ColumnLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(4 * root.unit)

      Repeater {
        model: root.cur ? [
          { icon: 0xF050F, text: Translations.t("lockWxFeels") + " " + root.tmp(root.cur.feels) },
          { icon: 0xF058E, text: Translations.t("lockWxHumidity") + " " + Math.round(root.cur.humidity) + "%" },
          { icon: 0xF059D, text: root.windText(root.cur.wind) }
        ] : []

        delegate: Row {
          required property var modelData
          spacing: Math.round(8 * root.unit)

          Text {
            text: root.glyph(modelData.icon)
            color: Theme.primary
            font.pixelSize: Math.round(14 * root.unit)
            font.family: Theme.monoFamily
          }
          Text {
            text: modelData.text
            color: Theme.subtext
            font.pixelSize: Math.round(12 * root.unit)
            font.family: Theme.fontFamily
          }
        }
      }
    }

    Rectangle {
      visible: root.forecast && root.upcoming.length > 0
      Layout.fillWidth: root.vertical
      Layout.preferredWidth: root.vertical ? -1 : 1
      Layout.preferredHeight: root.vertical ? 1 : Math.round(58 * root.unit)
      Layout.alignment: Qt.AlignVCenter
      color: Theme.divider
    }

    // ── Pronóstico ──
    RowLayout {
      visible: root.forecast && root.upcoming.length > 0
      Layout.fillWidth: root.vertical
      Layout.alignment: Qt.AlignVCenter
      spacing: Math.round(14 * root.unit)

      Repeater {
        model: root.upcoming

        delegate: Column {
          required property var modelData
          Layout.fillWidth: root.vertical
          spacing: Math.round(2 * root.unit)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dayName(modelData.date)
            color: Theme.subtext
            font.pixelSize: Math.round(11 * root.unit)
            font.bold: true
            font.family: Theme.fontFamily
          }
          WeatherIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(28 * root.unit)
            height: width
            code: modelData.code
            isDay: true
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tmp(modelData.max)
            color: Theme.text
            font.pixelSize: Math.round(12 * root.unit)
            font.bold: true
            font.family: Theme.fontFamily
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tmp(modelData.min)
            color: Theme.subtext
            font.pixelSize: Math.round(11 * root.unit)
            font.family: Theme.fontFamily
          }
        }
      }
    }
  }
}
