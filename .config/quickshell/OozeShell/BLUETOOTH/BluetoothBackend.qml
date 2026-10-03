// BluetoothBackend — estado y acciones de Bluetooth (BlueZ, vía Quickshell.Bluetooth).
//
// Requiere BlueZ y DBus corriendo. Si no hay adaptador, `available` es false.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../LANG"

Singleton {
  id: root

  // ─── Quién está mirando ────────────────────────────────────────
  // El panel lo pone en true mientras está abierto: enciende el escaneo.
  property bool panelWatch: false
  // El botón de refrescar del panel lo enciende/apaga (se reinicia al abrir)
  property bool scanRequested: true

  // ─── Adaptador ─────────────────────────────────────────────────
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool available: adapter !== null && adapter !== undefined
  readonly property bool enabled: available ? adapter.enabled : false
  readonly property bool scanning: available ? adapter.discovering : false

  function setEnabled(on) {
    if (root.available) root.adapter.enabled = on
  }

  // Escaneo: solo con el panel abierto y el adaptador encendido
  Binding {
    target: root.adapter
    property: "discovering"
    value: root.scanRequested && root.enabled
    when: root.available && root.panelWatch
  }

  onPanelWatchChanged: {
    if (panelWatch) scanRequested = true
    else if (available) adapter.discovering = false
  }

  // ─── Dispositivos ──────────────────────────────────────────────
  readonly property var allDevices: available ? adapter.devices.values : []

  readonly property var connectedDevices: allDevices.filter(d => d.connected)

  // BlueZ le pone la dirección MAC como nombre a los que no tienen uno:
  // esos solo estorban en la lista (salvo que ya estén emparejados).
  function looksLikeAddress(n) {
    return n === "" || /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(n)
  }

  function isBusy(d) {
    return d.pairing
      || d.state === BluetoothDeviceState.Connecting
      || d.state === BluetoothDeviceState.Disconnecting
  }

  function rank(d) {
    if (d.connected || root.isBusy(d)) return 0
    if (d.paired) return 1
    return 2
  }

  // Conectados / en curso primero, luego emparejados, luego el resto
  readonly property var devices: {
    const list = root.allDevices.filter(d => d.paired || d.connected || !root.looksLikeAddress(d.name))
    return list.sort((a, b) => (root.rank(a) - root.rank(b)) || String(a.name).localeCompare(String(b.name)))
  }

  // ─── Textos / íconos ───────────────────────────────────────────
  readonly property string summary: {
    if (!available) return "—"
    if (!enabled) return Translations.t("btOffSummary")
    const n = connectedDevices.length
    if (n === 0) return Translations.t("btOnSummary")
    if (n === 1) return connectedDevices[0].name
    return n + " " + Translations.t("btDevices")
  }

  readonly property string statusIcon: {
    if (!available || !enabled) return "󰂲"
    return connectedDevices.length > 0 ? "󰂱" : "󰂯"
  }

  // Ícono del tipo de dispositivo (BlueZ da nombres de ícono freedesktop)
  function deviceGlyph(icon) {
    const i = String(icon || "")
    if (i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1) return "󰋋"
    if (i.indexOf("audio") !== -1) return "󰓃"
    if (i.indexOf("keyboard") !== -1) return "󰌌"
    if (i.indexOf("mouse") !== -1 || i.indexOf("tablet") !== -1) return "󰍽"
    if (i.indexOf("gaming") !== -1) return "󰊗"
    if (i.indexOf("phone") !== -1) return "󰏲"
    if (i.indexOf("computer") !== -1) return "󰌢"
    return "󰂯"
  }

  function statusText(d) {
    if (d.pairing) return Translations.t("btPairing")
    if (d.state === BluetoothDeviceState.Connecting) return Translations.t("btConnecting")
    if (d.state === BluetoothDeviceState.Disconnecting) return Translations.t("btDisconnecting")
    if (d.connected) {
      const bat = d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : ""
      return Translations.t("btConnected") + bat
    }
    if (d.paired) return Translations.t("btPaired")
    return ""
  }

  // ─── Acciones ──────────────────────────────────────────────────
  // Dispositivo que se está emparejando: apenas queda emparejado se
  // marca como confiable y se conecta (un solo clic hace todo).
  property var pairingDevice: null

  Connections {
    target: root.pairingDevice
    ignoreUnknownSignals: true

    function onPairedChanged() {
      const d = root.pairingDevice
      if (d && d.paired) {
        root.pairingDevice = null
        d.trusted = true
        d.connect()
      }
    }

    function onPairingChanged() {
      const d = root.pairingDevice
      if (d && !d.pairing && !d.paired) root.pairingDevice = null
    }
  }

  // Clic en un dispositivo: conectado → desconecta, emparejado → conecta,
  // nuevo → empareja (y conecta al terminar). Ignora clics mientras hay
  // una operación en curso.
  function activate(d) {
    if (root.isBusy(d)) return
    if (d.connected) d.disconnect()
    else if (d.paired) d.connect()
    else {
      root.pairingDevice = d
      d.pair()
    }
  }

  function forget(d) {
    if (root.pairingDevice === d) root.pairingDevice = null
    d.forget()
  }
}
