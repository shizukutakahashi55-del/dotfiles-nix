// HyprState — backend de Hyprland (único archivo que importa Quickshell.Hyprland).
//
// Nadie lo usa directo: WM.qml lo expone en la forma común (monitores, ventanas,
// workspaces, fullscreen, layout de teclado). Es un singleton perezoso: solo se
// crea si algo lo nombra, o sea solo cuando el WM efectivo es Hyprland.
//
// Formas normalizadas (las mismas en los tres backends):
//   monitor  { name, id, x, y, width, height, scale, transform, focused, activeWorkspaceId }
//   ventana  { address, class, initialClass, title, workspace:{id,name}, monitor (NOMBRE),
//              at:[x,y], size:[w,h], floating, focusHistoryID (0 = con foco), mapped, hidden }
//   workspace: los objetos vivos de Quickshell.Hyprland (id, name, active, urgent, monitor, activate())
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  // ─── Workspaces ─────────────────────────────────────────────────
  // Objetos vivos (no copias): así los chips animan al cambiar `active` en vez
  // de reconstruirse. Normales por número, después los especiales.
  readonly property var workspaces: {
    const all = Hyprland.workspaces.values.slice()
    const normal  = all.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    const special = all.filter(w => w.id <= 0).sort((a, b) => b.id - a.id)
    return normal.concat(special)
  }

  readonly property string focusedMonitorName: Hyprland.focusedMonitor ? (Hyprland.focusedMonitor.name || "") : ""

  function activeWorkspaceId(screenName) {
    const list = Hyprland.monitors.values
    for (let i = 0; i < list.length; i++) {
      if (list[i].name === screenName)
        return list[i].activeWorkspace ? list[i].activeWorkspace.id : -999
    }
    return -999
  }

  // ─── Fullscreen ─────────────────────────────────────────────────
  // Solo fullscreen real (maximizada no cuenta). `lastIpcObject` se actualiza
  // al refrescar: se pide ante cualquier evento que pueda cambiarlo.
  function hasFullscreen(screen) {
    if (!screen) return false
    const mon = Hyprland.monitorFor(screen)
    const ws = mon ? mon.activeWorkspace : null
    const o = ws ? ws.lastIpcObject : null
    return o ? o.hasfullscreen === true : false
  }

  Timer {
    id: wsRefreshTimer
    interval: 40
    repeat: false
    onTriggered: Hyprland.refreshWorkspaces()
  }

  // ─── Toplevel de Wayland de una ventana (para capturarla) ───────
  // hyprctl da la dirección como "0x55d1…": se compara sin prefijo y en minúsculas.
  function normAddr(a) { return String(a || "").toLowerCase().replace(/^0x/, "") }
  function toplevelFor(address) {
    const model = Hyprland.toplevels
    const list = model ? model.values : []
    const want = root.normAddr(address)
    for (let i = 0; i < list.length; i++) {
      if (root.normAddr(list[i].address) === want) return list[i].wayland ?? null
    }
    return null
  }

  // ─── Monitores y ventanas (hyprctl -j) ──────────────────────────
  // Solo se mantienen al día mientras alguien los pide (retain/release): ni el
  // overview ni el launcher necesitan consultar hyprctl con todo cerrado.
  property var monitors: []
  property var clients: []
  property string lastRaw: ""

  property var users: ({})
  property int userCount: 0
  property var waiters: []
  property bool dirty: false

  function retain(key) {
    if (root.users[key]) return
    root.users[key] = true
    root.userCount++
    if (root.userCount === 1) root.refresh()
  }
  function release(key) {
    if (!root.users[key]) return
    delete root.users[key]
    root.userCount--
  }

  // cb(lista de ventanas) cuando termine la próxima lectura
  function snapshot(cb) {
    if (cb) root.waiters.push(cb)
    root.refresh()
  }

  function refresh() {
    if (snapProc.running) root.dirty = true
    else snapProc.running = true
  }

  function normMonitors(raw) {
    return raw.map(m => ({
      name: m.name, id: m.id, x: m.x, y: m.y, width: m.width, height: m.height,
      scale: m.scale, transform: m.transform ?? 0, focused: m.focused === true,
      activeWorkspaceId: m.activeWorkspace ? m.activeWorkspace.id : 0
    }))
  }

  function normClients(raw, mons) {
    const nameById = {}
    for (const m of mons) nameById[m.id] = m.name
    return raw.filter(c => c.mapped !== false && !c.hidden).map(c => ({
      address: c.address,
      "class": c["class"] || "",
      initialClass: c.initialClass || "",
      title: c.title || "",
      workspace: c.workspace ? { id: c.workspace.id, name: String(c.workspace.name) } : { id: 0, name: "" },
      monitor: nameById[c.monitor] ?? "",
      at: c.at, size: c.size,
      floating: c.floating === true,
      focusHistoryID: c.focusHistoryID ?? 999,
      mapped: true, hidden: false
    }))
  }

  Process {
    id: snapProc
    // Un solo proceso para las dos consultas; el marcador separa los dos JSON
    command: ["sh", "-c", "hyprctl monitors -j; echo '@@OOZE@@'; hyprctl clients -j"]
    property string buffer: ""
    stdout: SplitParser { onRead: line => snapProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const raw = snapProc.buffer
      snapProc.buffer = ""
      if (raw !== "" && raw !== root.lastRaw) {
        try {
          const parts = raw.split("@@OOZE@@")
          const mons = root.normMonitors(JSON.parse(parts[0]))
          root.monitors = mons
          root.clients = root.normClients(JSON.parse(parts[1]), mons)
          root.lastRaw = raw
        } catch (e) {
          console.log("HyprState: error leyendo hyprctl:", e)
        }
      }
      const cbs = root.waiters
      root.waiters = []
      for (const cb of cbs) cb(root.clients)
      // Llegó un evento mientras leía: una vuelta más
      if (root.dirty) {
        root.dirty = false
        Qt.callLater(() => root.refresh())
      }
    }
  }

  Timer {
    id: clientsTimer
    interval: 120
    repeat: false
    onTriggered: root.refresh()
  }

  // ─── Layout de teclado ──────────────────────────────────────────
  // KeyboardLayout.qml pone `kbPreferred` y lee `kbLayout`.
  property string kbPreferred: ""
  property string kbTracked: ""
  property string kbLayout: ""

  function kbRefresh() { if (!kbProc.running) kbProc.running = true }
  function kbNext(all) {
    Quickshell.execDetached([
      "hyprctl", "switchxkblayout",
      all ? "all" : (root.kbTracked !== "" ? root.kbTracked : root.kbPreferred),
      "next"
    ])
    // Red de seguridad por si el evento "activelayout" no llega
    kbSettle.restart()
  }

  Timer { id: kbSettle; interval: 250; repeat: false; onTriggered: root.kbRefresh() }

  Process {
    id: kbProc
    command: ["hyprctl", "devices", "-j"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => kbProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = buffer
      buffer = ""
      if (raw === "") return
      try {
        const kbs = JSON.parse(raw).keyboards || []
        const kb = kbs.find(k => k.name === root.kbPreferred) || kbs.find(k => k.main) || kbs[0]
        if (kb) { root.kbTracked = kb.name; root.kbLayout = kb.active_keymap }
      } catch (e) {
        console.log("HyprState: error leyendo hyprctl devices:", e)
      }
    }
  }

  // ─── Eventos de Hyprland ────────────────────────────────────────
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      const n = event.name

      // Layout de teclado: "activelayout>>teclado,Nombre del layout"
      if (n === "configreloaded") {
        root.kbRefresh()
      } else if (n === "activelayout") {
        const prefix = root.kbTracked + ","
        if (root.kbTracked !== "" && event.data.indexOf(prefix) === 0) root.kbLayout = event.data.slice(prefix.length)
        else if (root.kbTracked === "") root.kbRefresh()
        // Evento de otro teclado: se ignora a propósito
        return
      }

      // Fullscreen (siempre vivo: las barras se esconden con él)
      switch (n) {
        case "fullscreen": case "workspace": case "workspacev2": case "focusedmon":
        case "focusedmonv2": case "activewindow": case "closewindow": case "openwindow":
        case "movewindow": case "movewindowv2":
          wsRefreshTimer.restart()
          break
      }

      // Monitores y ventanas: solo si alguien los está mirando
      if (root.userCount > 0) {
        if (n === "configreloaded" || n.indexOf("monitor") === 0) root.refresh()
        else clientsTimer.restart()
      }
    }
  }

  Component.onCompleted: Hyprland.refreshWorkspaces()
}
