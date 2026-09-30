// BatteryBackend — estado de la batería, vía la API nativa de Quickshell
// (Quickshell.Services.UPower), mismo criterio que AudioBackend usa
// Quickshell.Services.Pipewire: sin sondeo manual, UPowerDevice ya es
// reactivo (cambia solo cuando cambia de verdad).
//
// Lo consume el módulo "battery" de BAR/RIGHT/RightModules.qml. Si la
// máquina no tiene batería (de escritorio), `available` queda en false y
// el módulo no se muestra aunque Theme.batteryEnabled esté en ON.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
  id: root

  readonly property UPowerDevice device: UPower.displayDevice

  readonly property bool available: !!root.device && root.device.isLaptopBattery && root.device.isPresent
  readonly property real percentage: root.device ? root.device.percentage : 0   // 0..1

  readonly property bool charging:
    root.device && (root.device.state === UPowerDeviceState.Charging
                     || root.device.state === UPowerDeviceState.PendingCharge)
  readonly property bool fullyCharged: root.device && root.device.state === UPowerDeviceState.FullyCharged
  readonly property bool isLow: root.available && root.percentage <= 0.20 && !root.charging

  // Segundos hasta vaciarse / cargarse del todo (0 si UPower no lo sabe)
  readonly property int timeToEmpty: root.device ? root.device.timeToEmpty : 0
  readonly property int timeToFull: root.device ? root.device.timeToFull : 0

  readonly property string icon: {
    if (root.charging) return "󰂄"
    if (root.fullyCharged || root.percentage >= 0.95) return "󰁹"
    if (root.percentage >= 0.60) return "󰂀"
    if (root.percentage >= 0.40) return "󰁾"
    if (root.percentage >= 0.20) return "󰁻"
    return "󰂎"
  }

  // "1h 20m" / "35m" — para el tooltip de la barra
  function formatSecs(s) {
    if (!s || s <= 0) return ""
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    return h > 0 ? (h + "h " + m + "m") : (m + "m")
  }
}
