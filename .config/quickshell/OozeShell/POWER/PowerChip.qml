// PowerChip — chip informativo (ícono + texto) del menú de energía.
// Mismo lenguaje que los chips del lock y de DashboardPower: píldora con el acento al ~16 % (CoOzey: caja cuadrada con contorno de tinta). `battery: true` dibuja la batería (BatteryIcon) en vez del glifo `icon`.

import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../BATTERY"

Rectangle {
  id: chip

  property string icon: ""
  property string text: ""
  property color tone: Theme.primary
  property bool battery: false
  property real unit: 1

  implicitWidth: row.implicitWidth + Math.round(22 * unit)
  implicitHeight: Math.round(30 * unit)
  radius: Theme.cozy ? 3 : height / 2
  color: Qt.rgba(tone.r, tone.g, tone.b, Theme.cozy ? 0.24 : 0.16)
  border.width: Theme.cozy ? 2 : 0
  border.color: Theme.ink

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Math.round(6 * chip.unit)

    Text {
      visible: !chip.battery
      text: chip.icon
      color: chip.tone
      font.pixelSize: Math.round(14 * chip.unit)
      font.family: Theme.monoFamily
    }
    BatteryIcon {
      visible: chip.battery
      Layout.alignment: Qt.AlignVCenter
      percentage: BatteryBackend.percentage
      charging: BatteryBackend.charging
      full: BatteryBackend.fullyCharged
      low: BatteryBackend.isLow
      iconHeight: Math.max(10, Math.round(13 * chip.unit))
    }
    Text {
      text: chip.text
      color: Theme.text
      font.pixelSize: Math.round(13 * chip.unit)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }
}
