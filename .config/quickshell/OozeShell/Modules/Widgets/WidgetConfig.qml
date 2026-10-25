// WidgetConfig — estado y persistencia de los widgets.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"
import "../../Core/Toml.js" as Toml

Singleton {
  id: root

  readonly property string file: Theme.prefsDir + "/widgets.toml"
  readonly property string legacyFile: Theme.prefsDir + "/widgets.json"

  property string layer: "bottom"

  property bool widgetsEnabled: true

  property int globalOpacity: -1
  property int globalBlur: -1
  property int globalBorder: -1
  property bool freeMove: false
  property string quickSide: "right"

  readonly property int gridGap: 16
  readonly property int marginX: 24
  readonly property int marginY: 64
  function setEnabled(on) { if (!!on === root.widgetsEnabled) return; root.widgetsEnabled = !!on; root.save() }
  function percentOr(v, def) {
    const n = parseInt(v)
    return isNaN(n) ? def : Math.max(-1, Math.min(100, n))
  }
  function setGlobalOpacity(v) {
    const n = root.percentOr(v, -1)
    if (n === root.globalOpacity) return
    root.globalOpacity = n
    root.save()
  }
  function setGlobalBlur(v) {
    const n = root.percentOr(v, -1)
    if (n === root.globalBlur) return
    root.globalBlur = n
    root.save()
  }
  function setGlobalBorder(v) {
    const n = (v === 0 || v === 1) ? v : -1
    if (n === root.globalBorder) return
    root.globalBorder = n
    root.save()
  }
  function setFreeMove(on) {
    if (!!on === root.freeMove) return
    root.freeMove = !!on
    root.save()
  }
  function setQuickSide(side) {
    const n = side === "left" ? "left" : "right"
    if (n === root.quickSide) return
    root.quickSide = n
    root.save()
  }
  function toggleQuickSide() { root.setQuickSide(root.quickSide === "left" ? "right" : "left") }
  function openQuick(id, monitor) {
    if (id !== "" && root.byId[id]) root.quickId = id
    root.quickMonitor = monitor ?? ""
    root.menuOpen = false
    root.quickOpen = true
  }
  function closeQuick() { root.quickOpen = false }
  function openMenu(id, monitor, x, y) {
    root.menuId = id
    root.menuMonitor = monitor
    root.menuX = x
    root.menuY = y
    root.menuOpen = true
  }
  function closeMenu() { root.menuOpen = false }
  property var widgets: []
  property var byId: ({})
  property var enabledIds: []
  property var allIds: []
  property bool editMode: false

  property bool quickOpen: false
  property string quickId: ""
  property string quickMonitor: ""

  property bool menuOpen: false
  property string menuId: ""
  property string menuMonitor: ""
  property real menuX: 0
  property real menuY: 0

  property bool loaded: false
  property string lastWritten: ""


  signal raiseRequested()
  signal widgetRemoved(string id)

  // ─── Derivados ─────────────────────────────────────────────────
  function rebuild() {
    const map = {}
    const ids = []
    const all = []
    for (const w of root.widgets) {
      if (!WidgetRegistry.has(w.type)) continue
      map[w.id] = w
      all.push(w.id)
      if (w.enabled) ids.push(w.id)
    }
    root.byId = map


    if (JSON.stringify(all) !== JSON.stringify(root.allIds)) root.allIds = all


    if (JSON.stringify(ids) !== JSON.stringify(root.enabledIds)) root.enabledIds = ids
  }

  function normalize(w) {
    if (!w || typeof w.id === "undefined" || typeof w.type !== "string") return null
    const t = WidgetRegistry.get(w.type)
    if (!t) return w
    const style = t.styles.indexOf(w.style) >= 0 ? w.style : t.styles[0]
    const sz = WidgetRegistry.sizeFor(w.type, style)
    return {
      id: String(w.id), type: w.type, style: style,
      x: Math.round(Number(w.x ?? 80)), y: Math.round(Number(w.y ?? 80)),
      w: Math.max(40, Math.round(Number(w.w ?? sz[0]))),
      h: Math.max(40, Math.round(Number(w.h ?? sz[1]))),
      monitor: String(w.monitor ?? ""),
      enabled: w.enabled !== false,
      options: Object.assign({}, t.defaults, w.options || {})
    }
  }

  // ─── Lectura ───────────────────────────────────────────────────
  function load(text) {
    const raw = (text || "").trim()
    if (raw !== "" && raw === root.lastWritten) { root.loaded = true; return }
    try {
      if (raw !== "") {
        const j = Toml.parseAny(raw)
        root.layer = (j.layer === "background") ? "background" : "bottom"
        root.widgetsEnabled = j.widgetsEnabled !== false
        root.globalOpacity = root.percentOr(j.globalOpacity, -1)
        root.globalBlur = root.percentOr(j.globalBlur, -1)
        root.globalBorder = (j.globalBorder === 0 || j.globalBorder === 1) ? j.globalBorder : -1
        root.freeMove = j.freeMove === true
        root.quickSide = j.quickSide === "left" ? "left" : "right"
        root.widgets = (Array.isArray(j.widgets) ? j.widgets : []).map(root.normalize).filter(w => w)
          .map(root.clampToScreen)
      } else {
        root.widgets = []
      }
    } catch (e) {
      console.log("[widgets] widgets.toml inválido, lo ignoro:", e)
    }
    root.loaded = true
    root.rebuild()
  }

  FileView {
    id: view
    path: root.file
    watchChanges: true
    onFileChanged: view.reload()
    onLoaded: root.load(view.text())
    onLoadFailed: legacyView.path = root.legacyFile
  }

  FileView {
    id: legacyView
    onLoaded: { root.load(legacyView.text()); root.save() }
    onLoadFailed: { root.loaded = true; root.rebuild() }
  }

  // ─── Escritura (con retardo: arrastrar no escribe en cada píxel) ───
  function serialize() {
    return Toml.stringify({ version: 1, layer: root.layer, widgetsEnabled: root.widgetsEnabled,
      globalOpacity: root.globalOpacity, globalBlur: root.globalBlur, globalBorder: root.globalBorder,
      freeMove: root.freeMove, quickSide: root.quickSide, widgets: root.widgets })
  }
  function save() { saveTimer.restart() }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: {
      const text = root.serialize()
      root.lastWritten = text.trim()
      writer.payload = text
      if (writer.running) writer.pending = true
      else writer.running = true
    }
  }

  Process {
    id: writer
    property string payload: ""
    property bool pending: false
    command: ["bash", "-c",
      'mkdir -p "$OOZE_DIR" && printf %s "$OOZE_DATA" > "$OOZE_FILE.tmp" && mv "$OOZE_FILE.tmp" "$OOZE_FILE" && { [ -f "$OOZE_LEGACY" ] && mv -f "$OOZE_LEGACY" "$OOZE_LEGACY.bak"; true; }']
    environment: ({ "OOZE_DATA": writer.payload, "OOZE_DIR": Theme.prefsDir, "OOZE_FILE": root.file, "OOZE_LEGACY": root.legacyFile })
    running: false
    onRunningChanged: {
      if (running || !pending) return
      pending = false
      running = true
    }
  }

  // ─── Operaciones ───────────────────────────────────────────────
  function indexOf(id) { return root.widgets.findIndex(w => w.id === id) }

  // ─── Colocación automática ─────────────────────────────────────
  function screenFor(monitor) {
    return Quickshell.screens.find(s => s.name === monitor) ?? Quickshell.screens[0] ?? null
  }
  function screenKey(monitor) {
    const s = root.screenFor(monitor)
    return s ? s.name : ""
  }

  // Nada queda fuera de la pantalla: si el monitor encogió o desapareció, se recoloca.
  function clampToScreen(o) {
    const scr = root.screenFor(o.monitor)
    if (!scr) return o
    o.w = Math.max(40, Math.min(Math.round(Number(o.w) || 40), scr.width))
    o.h = Math.max(40, Math.min(Math.round(Number(o.h) || 40), scr.height))
    o.x = Math.max(0, Math.min(Math.round(Number(o.x) || 0), scr.width - o.w))
    o.y = Math.max(0, Math.min(Math.round(Number(o.y) || 0), scr.height - o.h))
    return o
  }
  function rectsOf(monitor, skipId) {
    const key = root.screenKey(monitor)
    const out = []
    for (const o of root.widgets) {
      if (!o.enabled || o.id === skipId || root.screenKey(o.monitor) !== key) continue
      out.push({ x: o.x, y: o.y, w: o.w, h: o.h })
    }
    return out
  }
  function overlaps(a, b, gap) {
    return a.x < b.x + b.w + gap && b.x < a.x + a.w + gap && a.y < b.y + b.h + gap && b.y < a.y + a.h + gap
  }
  function collides(w) {
    return root.rectsOf(w.monitor, w.id).some(r => root.overlaps(w, r, 0))
  }
  function cascade(n) {
    const off = 40 * (n % 8)
    return { x: root.marginX + off, y: root.marginY + off }
  }
  function findSlot(w, h, rects, monitor) {
    const scr = root.screenFor(monitor)
    const sw = scr ? scr.width : 1920
    const sh = scr ? scr.height : 1080
    const g = root.gridGap
    const xs = [root.marginX]
    const ys = [root.marginY]
    for (const r of rects) {
      xs.push(r.x, r.x + r.w + g)
      ys.push(r.y, r.y + r.h + g)
    }
    xs.sort((a, b) => a - b)
    ys.sort((a, b) => a - b)
    for (const y of ys) {
      for (const x of xs) {
        if (x + w > sw - root.marginX || y + h > sh - root.marginY) continue
        const c = { x: x, y: y, w: w, h: h }
        if (!rects.some(r => root.overlaps(c, r, g))) return { x: x, y: y }
      }
    }
    return root.cascade(rects.length)
  }
  function slotFor(w) {
    return root.findSlot(w.w, w.h, root.rectsOf(w.monitor, w.id), w.monitor)
  }
  function arrange() {
    const lists = {}
    const arr = root.widgets.map(o => Object.assign({}, o))
    for (const o of arr) {
      if (!o.enabled) continue
      const key = root.screenKey(o.monitor)
      const list = lists[key] ?? (lists[key] = [])
      const s = root.findSlot(o.w, o.h, list, o.monitor)
      o.x = s.x
      o.y = s.y
      list.push({ x: o.x, y: o.y, w: o.w, h: o.h })
    }
    root.widgets = arr
    root.rebuild()
    root.save()
  }

  function update(id, patch) {
    const i = root.indexOf(id)
    if (i < 0) return false
    const arr = root.widgets.slice()
    const merged = Object.assign({}, arr[i], patch)
    if (patch.enabled === true && !arr[i].enabled && root.collides(merged)) {
      const s = root.slotFor(merged)
      merged.x = s.x
      merged.y = s.y
    }
    if (patch.monitor !== undefined || patch.x !== undefined || patch.y !== undefined
        || patch.w !== undefined || patch.h !== undefined) root.clampToScreen(merged)
    arr[i] = merged
    root.widgets = arr
    root.rebuild()
    root.save()
    return true
  }

  function add(type, style) {
    const t = WidgetRegistry.get(type)
    if (!t) return ""
    let n = 1
    while (root.indexOf(type + "-" + n) >= 0) n++
    const id = type + "-" + n
    const st = t.styles.indexOf(style) >= 0 ? style : t.styles[0]
    const sz = WidgetRegistry.sizeFor(type, st)
    const spot = root.findSlot(sz[0], sz[1], root.rectsOf("", id), "")
    root.widgets = root.widgets.concat([root.clampToScreen({
      id: id, type: type, style: st,
      x: spot.x, y: spot.y, w: sz[0], h: sz[1],
      monitor: "", enabled: true, options: Object.assign({}, t.defaults)
    })])
    root.rebuild()
    root.save()
    return id
  }

  function remove(id) {
    if (root.indexOf(id) < 0) return false
    root.widgets = root.widgets.filter(w => w.id !== id)
    root.rebuild()
    root.save()
    root.widgetRemoved(id)
    return true
  }

  function setStyle(id, style) {
    const i = root.indexOf(id)
    if (i < 0) return false
    const t = WidgetRegistry.get(root.widgets[i].type)
    if (!t || t.styles.indexOf(style) < 0) return false
    const sz = WidgetRegistry.sizeFor(t.id, style)
    const patch = { style: style, w: sz[0], h: sz[1] }
    const merged = Object.assign({}, root.widgets[i], patch)
    if (merged.enabled && root.collides(merged)) {
      const s = root.slotFor(merged)
      patch.x = s.x
      patch.y = s.y
    }
    return root.update(id, patch)
  }

  function setOption(id, key, value) {
    const i = root.indexOf(id)
    if (i < 0) return false
    const o = Object.assign({}, root.widgets[i].options)
    o[key] = value
    return root.update(id, { options: o })
  }

  function setLayer(name) {
    root.layer = (name === "background") ? "background" : "bottom"
    root.save()
    root.raiseRequested()
  }
}
