// NetworkBackend — estado y acciones de red (NetworkManager, vía nmcli).

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Lang"

Singleton {
  id: root


  signal connectSucceeded(string ssid)

  // ─── Quién está mirando ────────────────────────────────────────
  property bool menuWatch: false
  property bool panelWatch: false


  property bool holdList: false
  readonly property bool watching: menuWatch || panelWatch

  // ─── Estado ────────────────────────────────────────────────────
  property bool wifiEnabled: true
  property string wifiDevice: ""
  property string wifiConn: ""
  property string activeEthernet: ""
  property string activeSsid: ""
  property int activeSignal: 0
  property var networks: []
  property var savedNames: []
  property bool scanning: false
  property string connectingSsid: ""
  property string needPasswordFor: ""
  property string errorText: ""
  property string networksKey: ""

  readonly property bool wifiConnected: activeSsid !== "" || wifiConn !== ""


  readonly property string summary: {
    if (wifiConnected) return activeSsid !== "" ? activeSsid : wifiConn
    if (activeEthernet !== "") return activeEthernet
    return wifiEnabled ? "—" : "Off"
  }


  readonly property string title: {
    if (wifiConnected) return Translations.t("netTitleWifi")
    if (activeEthernet !== "") return Translations.t("netTitleEthernet")
    return Translations.t("netTitle")
  }

  readonly property string statusIcon: {
    if (wifiConnected) return root.signalIcon(activeSignal > 0 ? activeSignal : 75)
    if (activeEthernet !== "") return "󰈀"
    return wifiEnabled ? "󰤯" : "󰖪"
  }

  // ─── Helpers ───────────────────────────────────────────────────
  function signalIcon(sig) {
    if (sig >= 75) return "󰤨"
    if (sig >= 50) return "󰤥"
    if (sig >= 25) return "󰤢"
    return "󰤟"
  }

  function isSecured(sec) { return sec !== "" && sec !== "--" }
  function isSaved(ssid) { return root.savedNames.indexOf(ssid) !== -1 }


  function splitTerse(line) {
    const out = []
    let cur = ""
    for (let i = 0; i < line.length; i++) {
      const c = line[i]
      if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++ }
      else if (c === ":") { out.push(cur); cur = "" }
      else cur += c
    }
    out.push(cur)
    return out
  }

  // ─── Parseo de salidas ─────────────────────────────────────────
  function applyStatus(lines) {
    let dev = "", conn = "", eth = ""
    for (const l of lines) {
      const f = root.splitTerse(l)
      if (f.length < 4) continue
      if (f[0] === "wifi") {
        if (dev === "") dev = f[2]
        if (f[1] === "connected") { dev = f[2]; conn = f[3] }
      } else if (f[0] === "ethernet" && f[1] === "connected") {
        eth = f[3]
      }
    }
    root.wifiDevice = dev
    root.wifiConn = conn
    root.activeEthernet = eth
  }

  function applyList(lines) {
    if (root.holdList) return

    const best = {}
    for (const l of lines) {
      const f = root.splitTerse(l)
      if (f.length < 4 || f[1] === "") continue
      const entry = {
        ssid: f[1],
        signal: parseInt(f[2]) || 0,
        security: f[3],
        active: f[0] === "*"
      }
      const cur = best[entry.ssid]
      if (!cur || entry.active || (!cur.active && entry.signal > cur.signal))
        best[entry.ssid] = entry
    }

    const arr = Object.values(best)
    arr.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))

    const act = arr.find(n => n.active)
    root.activeSsid = act ? act.ssid : ""
    root.activeSignal = act ? act.signal : 0


    const key = arr.map(n => n.ssid + "|" + n.security + "|" + n.active + "|" + Math.round(n.signal / 25)).join(";")
    if (key !== root.networksKey) {
      root.networksKey = key
      root.networks = arr
    }
  }

  // ─── Consultas ─────────────────────────────────────────────────
  Process {
    id: statusProc
    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "TYPE,STATE,DEVICE,CONNECTION", "device"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => statusProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      root.applyStatus(lines)
    }
  }

  Process {
    id: radioProc
    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "WIFI", "radio"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => radioProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      if (lines.length > 0) root.wifiEnabled = (lines[0].trim() === "enabled")
    }
  }

  Process {
    id: listProc
    property string rescan: "no"
    property var lines: []
    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
              "device", "wifi", "list", "--rescan", rescan]
    running: false
    stdout: SplitParser { onRead: line => listProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; root.scanning = (rescan === "yes"); return }
      root.scanning = false
      root.applyList(lines)
    }
  }

  Process {
    id: savedProc
    command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    running: false
    property var lines: []
    stdout: SplitParser { onRead: line => savedProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      const names = []
      for (const l of lines) {
        const f = root.splitTerse(l)
        if (f.length >= 2 && (f[1].indexOf("wireless") !== -1 || f[1] === "wifi")) names.push(f[0])
      }
      root.savedNames = names
    }
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
    if (!radioProc.running) radioProc.running = true
  }

  function startList(rescan) {
    if (listProc.running) {

      if (!rescan) return
      listProc.running = false
    }
    listProc.rescan = rescan ? "yes" : "no"
    listProc.running = true
  }

  function refreshSaved() {
    if (!savedProc.running) savedProc.running = true
  }

  function refreshAll() {
    root.refreshStatus()
    root.startList(false)
    root.refreshSaved()
  }


  function rescan() {
    root.refreshStatus()
    root.startList(true)
  }

  Timer {
    interval: 4000
    running: root.watching
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refreshStatus()
      root.startList(false)
    }
  }

  onPanelWatchChanged: {
    if (root.panelWatch) {
      root.errorText = ""
      root.needPasswordFor = ""
      root.refreshSaved()
      root.startList(true)
    }
  }

  // ─── Acciones ──────────────────────────────────────────────────

  Process {
    id: actionProc
    property var args: []
    command: ["env", "LC_ALL=C", "nmcli"].concat(args)
    running: false
    onRunningChanged: { if (!running) afterActionTimer.restart() }
  }

  Timer { id: afterActionTimer; interval: 400; repeat: false; onTriggered: root.refreshAll() }

  function runAction(args) {
    actionProc.running = false
    actionProc.args = args
    actionProc.running = true
  }

  function setWifi(on) {
    root.wifiEnabled = on
    root.networks = []
    root.networksKey = ""
    if (!on) { root.activeSsid = ""; root.wifiConn = ""; root.activeSignal = 0 }
    root.runAction(["radio", "wifi", on ? "on" : "off"])
  }

  function disconnectWifi() {
    if (root.wifiDevice === "") return
    root.runAction(["device", "disconnect", root.wifiDevice])
  }


  function forget(ssid) {
    root.runAction(["connection", "delete", "id", ssid])
  }

  Process {
    id: connectProc
    property string ssid: ""
    property string password: ""
    property bool wasSaved: false
    property var lines: []

    command: password !== ""
      ? ["env", "LC_ALL=C", "nmcli", "device", "wifi", "connect", ssid, "password", password]
      : ["env", "LC_ALL=C", "nmcli", "device", "wifi", "connect", ssid]
    running: false
    stdout: SplitParser { onRead: line => connectProc.lines.push(line) }
    stderr: SplitParser { onRead: line => connectProc.lines.push(line) }
    onRunningChanged: {
      if (running) { lines = []; return }
      root.connectFinished(lines.join("\n"), ssid, password !== "", wasSaved)
    }
  }

  function connectTo(ssid, password) {
    root.errorText = ""
    root.needPasswordFor = ""
    root.connectingSsid = ssid
    connectProc.ssid = ssid
    connectProc.password = password
    connectProc.wasSaved = root.isSaved(ssid)
    connectProc.running = false
    connectProc.running = true
  }

  function connectFinished(text, ssid, hadPassword, wasSaved) {
    root.connectingSsid = ""
    const t = text.toLowerCase()

    if (t.indexOf("successfully activated") !== -1) {
      root.errorText = ""
      root.needPasswordFor = ""
      root.connectSucceeded(ssid)
      root.refreshAll()
      return
    }

    if (t.indexOf("secrets were required") !== -1 || t.indexOf("no secrets") !== -1) {

      if (hadPassword) root.errorText = Translations.t("netWrongPass")
      else root.needPasswordFor = ssid
    } else {
      const errLine = text.split("\n").find(l => l.indexOf("Error") !== -1) ?? text.split("\n")[0]
      root.errorText = errLine.replace(/^Error:\s*/, "")
    }


    if (!wasSaved) root.forget(ssid)
    else root.refreshAll()
  }
}
