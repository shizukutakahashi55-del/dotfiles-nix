// MangoIpc — UNICA fuente de verdad del estado de MangoWM (mango).

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Backends/native"

Singleton {
  id: root

  // ─── Estado crudo (tal cual lo entrega mmsg) ───────────────────
  property var monitors: []
  property var clients: []
  property string keyboardLayoutName: ""
  property bool connected: false

  // ─── Derivados ────────────────────────────────────────────────
  readonly property string focusedMonitorName: {
    const m = root.monitors.find(x => x.active === true)
    return m ? m.name : ""
  }

  function monitorByName(name) {
    return root.monitors.find(m => m.name === name) ?? null
  }


  function workspacesFor(screenName, showAll) {
    const m = root.monitorByName(screenName) ?? root.monitors.find(x => x.active === true) ?? null
    if (!m || !m.tags) return []
    const out = []
    for (let i = 0; i < m.tags.length; i++) {
      const t = m.tags[i]
      if (showAll !== true && !t.is_active && !t.is_urgent && t.client_count === 0) continue
      out.push({
        id: t.index,
        name: String(t.index),
        active: t.is_active === true,
        urgent: t.is_urgent === true,
        clients: t.client_count,
        occupied: t.client_count > 0,
        monitor: m.name,
        activate: () => root.viewTag(t.index, m.name)
      })
    }
    return out
  }


  function activeTag(screenName) {
    const m = root.monitorByName(screenName)
    if (!m || !m.active_tags || m.active_tags.length === 0) return 0
    return m.active_tags[0]
  }


  function hasFullscreen(screenName) {
    const list = root.clients
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      if (c.monitor === screenName && c.is_fullscreen === true && c.is_visible === true) return true
    }
    return false
  }


  readonly property var clientsCompat: {
    const out = []
    const list = root.clients
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      if (c.is_minimized === true) continue
      out.push({
        address: String(c.id),
        "class": c.appid || "",
        initialClass: c.appid || "",
        title: c.title || "",
        tags: c.tags || [],
        workspace: { id: (c.tags && c.tags.length > 0) ? c.tags[0] : 0,
                     name: (c.tags && c.tags.length > 0) ? String(c.tags[0]) : "" },
        monitor: c.monitor,
        at: [c.x, c.y],
        size: [c.width, c.height],
        floating: c.is_floating === true,
        focusHistoryID: c.is_focused === true ? 0 : 1,
        mapped: true,
        hidden: false
      })
    }
    return out
  }


  readonly property var monitorsCompat: root.monitors.map(m => ({
    name: m.name, x: m.x, y: m.y, width: m.width, height: m.height,
    scale: 1, transform: 0, focused: m.active === true
  }))

  // ─── Acciones ──────────────────────────────────────────────────


  function dispatch(spec) {
    if (!/^[A-Za-z0-9_,.+\-: ]+$/.test(spec)) return
    Quickshell.execDetached(["mmsg", "dispatch", spec])
  }


  function viewTag(id, monitorName) {
    const n = parseInt(id)
    if (isNaN(n) || n < 1 || n > 32) return
    const mon = String(monitorName || "")
    if (mon !== "" && mon !== root.focusedMonitorName && /^[A-Za-z0-9_.:\-]+$/.test(mon))
      root.dispatch("viewcrossmon," + n + "," + mon)
    else
      root.dispatch("view," + n + ",0")
  }


  function focusClient(address) {
    const id = parseInt(address)
    if (isNaN(id) || id < 1) return
    const c = root.clients.find(x => x.id === id)
    let pre = ""
    if (c && c.tags && c.tags.length > 0 && /^[A-Za-z0-9_.:\-]+$/.test(String(c.monitor || ""))) {
      pre = "mmsg dispatch 'viewcrossmon," + parseInt(c.tags[0]) + "," + c.monitor + "'; "
    }
    Quickshell.execDetached(["sh", "-c", pre + "mmsg dispatch focusid 'client," + id + "'"])
  }

  function killFocused() { root.dispatch("killclient") }
  function nextKeyboardLayout() { root.dispatch("switch_keyboard_layout") }
  function quit() { Quickshell.execDetached(["mmsg", "dispatch", "quit"]) }


  function toplevelFor(address) {
    const id = parseInt(address)
    const c = root.clients.find(x => x.id === id)
    if (!c) return null
    const model = ToplevelManager.toplevels
    const list = model ? model.values : []
    let byApp = null, appCount = 0
    for (let i = 0; i < list.length; i++) {
      const t = list[i]
      if (t.appId !== c.appid) continue
      if (t.title === c.title) return t
      byApp = t; appCount++
    }
    return appCount === 1 ? byApp : null
  }

  // ─── Streams ───────────────────────────────────────────────────
  function parseLine(line) {
    try { return JSON.parse(line) } catch (e) { return null }
  }

  property bool nativeTried: false
  property var nativeMonitors: null
  property var nativeClients: null
  property var nativeKeyboard: null
  readonly property bool useNativeStreams: root.nativeMonitors !== null

  function ensureNativeStreams() {
    if (root.nativeTried) return
    root.nativeTried = true
    try {
      const mk = (args, onObj) => {
        const o = NativeSpec.probe('WmStream { }', root, "OozeWmStream")
        o.command = args
        o.parsed.connect(onObj)
        o.active = Qt.binding(() => WM.wm === "mango")
        return o
      }
      root.nativeMonitors = mk(["mmsg", "watch", "all-monitors"],
        obj => { if (obj && obj.monitors) { root.monitors = obj.monitors; root.connected = true } })
      root.nativeClients = mk(["mmsg", "watch", "all-clients"],
        obj => { if (obj && obj.clients) root.clients = obj.clients })
      root.nativeKeyboard = mk(["mmsg", "watch", "keyboardlayout"],
        obj => { if (obj && obj.layout !== undefined) root.keyboardLayoutName = obj.layout })
    } catch (e) {
      root.nativeMonitors = null
      root.nativeClients = null
      root.nativeKeyboard = null
    }
  }
  Component.onCompleted: root.ensureNativeStreams()

  Process {
    id: monitorsWatch
    command: ["mmsg", "watch", "all-monitors"]
    running: !root.useNativeStreams && WM.wm === "mango"
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.monitors) { root.monitors = j.monitors; root.connected = true }
      }
    }
    onExited: { if (WM.wm === "mango") restartTimer.restart() }
  }

  Process {
    id: clientsWatch
    command: ["mmsg", "watch", "all-clients"]
    running: !root.useNativeStreams && WM.wm === "mango"
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.clients) root.clients = j.clients
      }
    }
    onExited: { if (WM.wm === "mango") restartTimer.restart() }
  }

  Process {
    id: keyboardWatch
    command: ["mmsg", "watch", "keyboardlayout"]
    running: !root.useNativeStreams && WM.wm === "mango"
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.layout !== undefined) root.keyboardLayoutName = j.layout
      }
    }
    onExited: { if (WM.wm === "mango") restartTimer.restart() }
  }

  Connections {
    target: WM
    function onWmChanged() {
      const on = WM.wm === "mango" && !root.useNativeStreams
      if (on) {
        if (!monitorsWatch.running) monitorsWatch.running = true
        if (!clientsWatch.running) clientsWatch.running = true
        if (!keyboardWatch.running) keyboardWatch.running = true
      } else if (WM.wm !== "mango") {
        monitorsWatch.running = false
        clientsWatch.running = false
        keyboardWatch.running = false
        root.connected = false
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (WM.wm !== "mango" || root.useNativeStreams) return
      if (!monitorsWatch.running) monitorsWatch.running = true
      if (!clientsWatch.running)  clientsWatch.running = true
      if (!keyboardWatch.running) keyboardWatch.running = true
    }
  }
}
