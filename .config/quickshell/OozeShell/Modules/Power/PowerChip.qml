// PowerChip — chip informativo (ícono + texto) del menú de energía.

import QtQuick
import QtQuick.Layouts
import "../../COMMON"
import "../../Services/Battery"

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
      visible: !chip.battery
      text: chip.text
      color: Theme.text
      font.pixelSize: Math.round(13 * chip.unit)
      font.bold: true
      font.family: Theme.fontFamily
    }
  }
}
