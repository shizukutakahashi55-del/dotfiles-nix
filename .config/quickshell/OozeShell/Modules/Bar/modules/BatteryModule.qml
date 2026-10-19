// BatteryModule — porcentaje y estado de la batería; solo aparece si la máquina tiene batería y está activada en Ajustes.

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../../../Services/Lang"
import "../../../Services/Battery"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: Theme.batteryEnabled && BatteryBackend.available

  readonly property string batteryTip: {
    if (!BatteryBackend.available) return ""
    const pct = Math.round(BatteryBackend.percentage * 100) + "%"
    const state = BatteryBackend.fullyCharged ? Translations.t("batteryFull")
                : BatteryBackend.charging     ? Translations.t("batteryCharging")
                                              : Translations.t("batteryDischarging")
    const secs = BatteryBackend.charging ? BatteryBackend.timeToFull : BatteryBackend.timeToEmpty
    const time = BatteryBackend.formatSecs(secs)
    const timeLabel = BatteryBackend.charging ? Translations.t("batteryTimeToFull")
                                              : Translations.t("batteryTimeToEmpty")
    return pct + " — " + state + (time !== "" ? ("\n" + timeLabel + " " + time) : "")
  }

  BarPillButton {
    id: batteryBtn

    tip: mod.batteryTip

    onHoverEntered: mod.host.tipEnter(batteryBtn)
    onHoverExited: mod.host.tipLeave(batteryBtn)

    BatteryIcon {
      Layout.alignment: Qt.AlignHCenter
      percentage: BatteryBackend.percentage
      charging: BatteryBackend.charging
      full: BatteryBackend.fullyCharged
      low: BatteryBackend.isLow
      iconHeight: Math.max(10, Theme.fs(12))
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: Math.round(BatteryBackend.percentage * 100) + "%"
      color: BatteryBackend.isLow ? Theme.error : Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(12)
    }
  }
}
