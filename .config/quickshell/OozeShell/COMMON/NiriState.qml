// NiriState — backend de Niri (`niri msg --json event-stream` + `niri msg --json outputs`).
//
// Nadie lo usa directo: WM.qml lo expone en la forma común (ver HyprState.qml).
// Singleton perezoso: el stream solo arranca si el WM efectivo es Niri.
//
// El stream entrega el estado completo al conectar y después los cambios, así
// que no hay polling. Eventos usados (docs de niri-ipc, enum Event):
//   WorkspacesChanged, WorkspaceActivated, WorkspaceUrgencyChanged,
//   WindowsChanged, WindowOpenedOrChanged, WindowClosed, WindowFocusChanged,
//   WindowFocusTimestampChanged, WindowUrgencyChanged, WindowLayoutsChanged,
//   KeyboardLayoutsChanged, KeyboardLayoutSwitched, ConfigLoaded.
//
// Equivalencias con el resto de la shell:
//   • "workspace N" = el workspace de índice N DE ESE MONITOR (idx), no el id
//     global de niri: así Pill/Overview muestran 1, 2, 3… y las ventanas se
//     asocian por (monitor, idx), igual que los tags de Mango.
//   • Niri no informa fullscreen en `Window`: hasFullscreen() siempre es false.
//   • Las ventanas solo traen posición (`tile_pos_in_workspace_view`) cuando
//     están a la vista; las demás no se dibujan en las miniaturas del Overview.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
  id: root

  // ─── Estado crudo ───────────────────────────────────────────────
  property var wsById: ({})        // id → Workspace de niri
  property var winById: ({})       // id → Window de niri
  property var outputs: []         // monitores normalizados (de `niri msg outputs`)
  property bool connected: false

  property var kbNames: []
  property int kbIdx: -1
  readonly property string kbLayout: (root.kbIdx >= 0 && root.kbIdx < root.kbNames.length) ? root.kbNames[root.kbIdx] : ""

  // ─── Derivados ──────────────────────────────────────────────────
  readonly property string focusedMonitorName: {
    for (const k in root.wsById) if (root.wsById[k].is_focused === true && root.wsById[k].output) return root.wsById[k].output
    return ""
  }

  readonly property var monitors: root.outputs.map(o => ({
    name: o.name, id: o.name, x: o.x, y: o.y, width: o.width, height: o.height,
    // `logical` ya viene con escala y rotación aplicadas
    scale: 1, transform: 0, focused: o.name === root.focusedMonitorName,
    activeWorkspaceId: root.activeWorkspaceId(o.name)
  }))

  function activeWorkspaceId(outputName) {
    for (const k in root.wsById) {
      const w = root.wsById[k]
      if (w.output === outputName && w.is_active === true) return w.idx
    }
    return -999
  }

  // Ventanas por workspace (id global), para ocultar los workspaces vacíos
  readonly property var windowCountByWs: {
    const c = {}
    for (const k in root.winById) {
      const w = root.winById[k]
      if (w.workspace_id !== null && w.workspace_id !== undefined) c[w.workspace_id] = (c[w.workspace_id] || 0) + 1
    }
    return c
  }

  // Workspaces de un monitor ("" = el enfocado), como los muestra la barra
  function workspacesFor(screenName, includeSpecial) {
    const mon = screenName !== "" ? screenName : root.focusedMonitorName
    const out = []
    for (const k in root.wsById) {
      const w = root.wsById[k]
      if (w.output !== mon) continue
      const count = root.windowCountByWs[w.id] || 0
      // niri siempre deja un workspace vacío al final: no se muestra
      if (!w.is_active && !w.is_urgent && w.name === null && count === 0) continue
      out.push({
        id: w.idx,
        name: (w.name !== null && w.name !== undefined) ? String(w.name) : String(w.idx),
        active: w.is_active === true,
        urgent: w.is_urgent === true,
        special: false,
        clients: count,
        monitor: w.output,
        activate: () => root.focusWorkspace(w.output, w.idx)
      })
    }
    out.sort((a, b) => a.id - b.id)
    return out
  }

  // Ventanas en la forma común (ver HyprState.qml)
  readonly property var clients: {
    const mons = {}
    for (const o of root.outputs) mons[o.name] = o

    const list = []
    for (const k in root.winById) list.push(root.winById[k])
    // Más reciente primero; la que tiene el foco, 0
    const ts = w => w.focus_timestamp ? (w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos) : 0
    const order = list.slice().sort((a, b) => ts(b) - ts(a))
    const rank = {}
    order.forEach((w, i) => { rank[w.id] = i + 1 })

    const out = []
    for (const w of list) {
      const ws = (w.workspace_id !== null && w.workspace_id !== undefined) ? root.wsById[w.workspace_id] : null
      if (!ws) continue
      const mon = mons[ws.output]
      const L = w.layout || {}
      const tp = L.tile_pos_in_workspace_view
      const off = L.window_offset_in_tile || [0, 0]
      const ws_ = L.window_size || [0, 0]
      out.push({
        address: String(w.id),
        "class": w.app_id || "",
        initialClass: w.app_id || "",
        title: w.title || "",
        workspace: { id: ws.idx, name: (ws.name !== null && ws.name !== undefined) ? String(ws.name) : String(ws.idx) },
        monitor: ws.output || "",
        at: (tp && mon) ? [mon.x + tp[0] + off[0], mon.y + tp[1] + off[1]] : null,
        size: [ws_[0], ws_[1]],
        floating: w.is_floating === true,
        focusHistoryID: w.is_focused === true ? 0 : rank[w.id],
        mapped: true, hidden: false
      })
    }
    return out
  }

  // ─── Acciones ───────────────────────────────────────────────────
  // monitor: nombre de salida; idx: índice de workspace. Se validan antes de
  // viajar al shell, nunca se pega nada sin validar.
  function focusWorkspace(outputName, idx) {
    const n = parseInt(idx)
    if (isNaN(n) || n < 1) return
    const o = String(outputName || "")
    if (o !== "" && o !== root.focusedMonitorName && /^[A-Za-z0-9_.:\-]+$/.test(o)) {
      Quickshell.execDetached(["sh", "-c",
        'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"',
        "sh", o, String(n)])
    } else {
      Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(n)])
    }
  }

  function nextLayout() {
    Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
  }

  // Toplevel de Wayland (lo que ScreencopyView sabe capturar). Niri no da un
  // handle común: se busca por app_id + título.
  function toplevelFor(address) {
    const w = root.winById[parseInt(address)]
    if (!w) return null
    const model = ToplevelManager.toplevels
    const list = model ? model.values : []
    let byApp = null, appCount = 0
    for (let i = 0; i < list.length; i++) {
      const t = list[i]
      if (t.appId !== (w.app_id || "")) continue
      if (t.title === (w.title || "")) return t
      byApp = t; appCount++
    }
    return appCount === 1 ? byApp : null
  }

  // ─── Stream de eventos ──────────────────────────────────────────
  function applyEvent(ev) {
    let k = null
    for (const key in ev) { k = key; break }
    if (k === null) return
    const d = ev[k]

    switch (k) {
      case "WorkspacesChanged": {
        const m = {}
        let outsKey = ""
        for (const w of d.workspaces) { m[w.id] = w; outsKey += (w.output || "") + "|" }
        root.wsById = m
        // Cambió el conjunto de monitores (conectar / desconectar): releer posiciones
        if (outsKey !== root._outsKey) { root._outsKey = outsKey; outputsDebounce.restart() }
        root.connected = true
        break
      }
      case "WorkspaceActivated": {
        const t = root.wsById[d.id]
        if (!t) break
        const m = {}
        for (const key in root.wsById) {
          const w = root.wsById[key]
          const sameOut = w.output === t.output
          m[key] = Object.assign({}, w, {
            is_active: sameOut ? (w.id === d.id) : w.is_active,
            is_focused: d.focused ? (w.id === d.id) : w.is_focused
          })
        }
        root.wsById = m
        break
      }
      case "WorkspaceUrgencyChanged": {
        const w = root.wsById[d.id]
        if (!w) break
        const m = Object.assign({}, root.wsById)
        m[d.id] = Object.assign({}, w, { is_urgent: d.urgent })
        root.wsById = m
        break
      }
      case "WindowsChanged": {
        const m = {}
        for (const w of d.windows) m[w.id] = w
        root.winById = m
        break
      }
      case "WindowOpenedOrChanged": {
        const m = Object.assign({}, root.winById)
        // Con una ventana nueva con foco, las demás lo pierden
        if (d.window.is_focused === true)
          for (const key in m) if (m[key].is_focused) m[key] = Object.assign({}, m[key], { is_focused: false })
        m[d.window.id] = d.window
        root.winById = m
        break
      }
      case "WindowClosed": {
        const m = Object.assign({}, root.winById)
        delete m[d.id]
        root.winById = m
        break
      }
      case "WindowFocusChanged": {
        const m = {}
        for (const key in root.winById) {
          const w = root.winById[key]
          const f = (d.id !== null && d.id !== undefined && w.id === d.id)
          m[key] = (w.is_focused === f) ? w : Object.assign({}, w, { is_focused: f })
        }
        root.winById = m
        break
      }
      case "WindowFocusTimestampChanged": {
        const w = root.winById[d.id]
        if (!w) break
        const m = Object.assign({}, root.winById)
        m[d.id] = Object.assign({}, w, { focus_timestamp: d.focus_timestamp })
        root.winById = m
        break
      }
      case "WindowUrgencyChanged": {
        const w = root.winById[d.id]
        if (!w) break
        const m = Object.assign({}, root.winById)
        m[d.id] = Object.assign({}, w, { is_urgent: d.urgent })
        root.winById = m
        break
      }
      case "WindowLayoutsChanged": {
        const m = Object.assign({}, root.winById)
        for (const ch of d.changes) {
          const w = m[ch[0]]
          if (w) m[ch[0]] = Object.assign({}, w, { layout: ch[1] })
        }
        root.winById = m
        break
      }
      case "KeyboardLayoutsChanged":
        root.kbNames = d.keyboard_layouts.names || []
        root.kbIdx = d.keyboard_layouts.current_idx
        break
      case "KeyboardLayoutSwitched":
        root.kbIdx = d.idx
        break
      case "ConfigLoaded":
        outputsDebounce.restart()
        break
    }
  }

  property string _outsKey: ""
  property int restarts: 0

  Process {
    id: stream
    command: ["niri", "msg", "--json", "event-stream"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        let ev = null
        try { ev = JSON.parse(line) } catch (e) { return }
        if (ev) root.applyEvent(ev)
      }
    }
    // Si niri se reinicia el stream se reconecta, pero no para siempre
    // (si no es una sesión de niri, no insistas).
    onExited: {
      if (root.restarts < 5) { root.restarts++; restartTimer.restart() }
    }
  }
  Timer { id: restartTimer; interval: 1500; onTriggered: stream.running = true }

  // ─── Monitores (posición y tamaño lógicos) ──────────────────────
  Timer { id: outputsDebounce; interval: 200; onTriggered: if (!outputsProc.running) outputsProc.running = true }

  Process {
    id: outputsProc
    command: ["niri", "msg", "--json", "outputs"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => outputsProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = buffer
      buffer = ""
      if (raw === "") return
      try {
        const j = JSON.parse(raw)
        const list = []
        for (const name in j) {
          const o = j[name]
          const L = o.logical
          if (!L) continue                       // salida apagada
          list.push({ name: o.name || name, x: L.x ?? 0, y: L.y ?? 0, width: L.width, height: L.height, scale: L.scale ?? 1 })
        }
        root.outputs = list
      } catch (e) {
        console.log("NiriState: error leyendo niri outputs:", e)
      }
    }
  }
}
