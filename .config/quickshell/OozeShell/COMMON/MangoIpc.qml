// MangoIpc — UNICA fuente de verdad del estado de MangoWM (mango).
//
// Reemplaza a Quickshell.Hyprland + `hyprctl ... -j` + HyprDispatch del
// OozeShell original. Habla con el compositor a traves de `mmsg`
// (JSON por IPC, una linea por actualizacion):
//
//   mmsg watch all-monitors   → monitores, tags (workspaces), cliente activo
//   mmsg watch all-clients    → todas las ventanas
//   mmsg watch keyboardlayout → idioma del teclado
//   mmsg dispatch <func>,...  → acciones (view, focusid, killclient...)
//
// Requiere: mmsg (viene con Mango) y la variable MANGO_INSTANCE_SIGNATURE,
// que Mango exporta solo a todo lo que lanza (exec-once incluido).
//
// Conceptos:  workspace de Hyprland == TAG de Mango (1..tag_num, por monitor).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
  id: root

  // ─── Estado crudo (tal cual lo entrega mmsg) ───────────────────
  property var monitors: []          // [{name, active, x, y, width, height, scale, tags:[{index,is_active,is_urgent,client_count,layout}], active_tags, ...}]
  property var clients: []           // [{id, title, appid, monitor, tags:[..], is_focused, is_fullscreen, is_floating, is_visible, x, y, width, height, ...}]
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

  // "Workspaces" de un monitor, con la misma forma que usaba el shell con
  // Hyprland (id, name, active, urgent, activate()).
  // Como Hyprland, por defecto solo lista los que existen: activos, con
  // ventanas o urgentes. showAll = true lista los tag_num completos.
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
        monitor: m.name,
        activate: () => root.viewTag(t.index, m.name)
      })
    }
    return out
  }

  // Tag activo (el primero) de un monitor; 0 = desconocido / overview.
  function activeTag(screenName) {
    const m = root.monitorByName(screenName)
    if (!m || !m.active_tags || m.active_tags.length === 0) return 0
    return m.active_tags[0]
  }

  // ¿Hay una ventana en fullscreen real y visible en ese monitor?
  function hasFullscreen(screenName) {
    const list = root.clients
    for (let i = 0; i < list.length; i++) {
      const c = list[i]
      if (c.monitor === screenName && c.is_fullscreen === true && c.is_visible === true) return true
    }
    return false
  }

  // Ventanas con la forma que leian Overview / Launcher / Mpris (hyprctl).
  //   address = id de Mango (como texto)   class = appid
  //   tags    = lista de tags donde esta    at/size = geometria global
  //   focusHistoryID: 0 si tiene el foco (Mango no expone el historial)
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

  // Monitores con la forma de `hyprctl monitors -j` (mango ya entrega
  // coordenadas logicas, por eso scale = 1 y transform = 0).
  readonly property var monitorsCompat: root.monitors.map(m => ({
    name: m.name, x: m.x, y: m.y, width: m.width, height: m.height,
    scale: 1, transform: 0, focused: m.active === true
  }))

  // ─── Acciones ──────────────────────────────────────────────────
  // Los argumentos se validan (solo numeros / nombres de salida) antes de
  // viajar a `mmsg dispatch`, asi no hay forma de colar otro comando.
  function dispatch(spec) {
    if (!/^[A-Za-z0-9_,.+\-: ]+$/.test(spec)) return
    Quickshell.execDetached(["mmsg", "dispatch", spec])
  }

  // Ir al tag `id`. En otro monitor: viewcrossmon (lo enfoca y cambia su tag).
  function viewTag(id, monitorName) {
    const n = parseInt(id)
    if (isNaN(n) || n < 1 || n > 32) return
    const mon = String(monitorName || "")
    if (mon !== "" && mon !== root.focusedMonitorName && /^[A-Za-z0-9_.:\-]+$/.test(mon))
      root.dispatch("viewcrossmon," + n + "," + mon)
    else
      root.dispatch("view," + n + ",0")
  }

  // Enfoca una ventana por su id de Mango; si esta en otro tag, cambia a el.
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

  // Toplevel de Wayland (lo que ScreencopyView sabe capturar) de una ventana.
  // Mango no entrega un handle comun, asi que se busca por appid + titulo.
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

  Process {
    id: monitorsWatch
    command: ["mmsg", "watch", "all-monitors"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.monitors) { root.monitors = j.monitors; root.connected = true }
      }
    }
    onExited: restartTimer.restart()
  }

  Process {
    id: clientsWatch
    command: ["mmsg", "watch", "all-clients"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.clients) root.clients = j.clients
      }
    }
    onExited: restartTimer.restart()
  }

  Process {
    id: keyboardWatch
    command: ["mmsg", "watch", "keyboardlayout"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        const j = root.parseLine(line)
        if (j && j.layout !== undefined) root.keyboardLayoutName = j.layout
      }
    }
    onExited: restartTimer.restart()
  }

  // Si mmsg muere (recarga del compositor, etc.) se vuelve a conectar solo.
  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (!monitorsWatch.running) monitorsWatch.running = true
      if (!clientsWatch.running)  clientsWatch.running = true
      if (!keyboardWatch.running) keyboardWatch.running = true
    }
  }
}
