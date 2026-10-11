// WidgetConfig — estado y persistencia de los widgets.
// Archivo:  ~/.config/oozeshell/widgets.json

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../COMMON"

Singleton {
  id: root

  readonly property string file: Theme.prefsDir + "/widgets.json"

  property string layer: "bottom"

  property bool widgetsEnabled: true

  property int globalOpacity: -1
  property int globalBlur: -1
  function setEnabled(on) { if (!!on === root.widgetsEnabled) return; root.widgetsEnabled = !!on; root.save() }
  function setGlobalOpacity(v) {
    const n = Math.max(-1, Math.min(100, parseInt(v) ?? -1))
    if (n === root.globalOpacity) return
    root.globalOpacity = n
    root.save()
  }
  function setGlobalBlur(v) {
    const n = Math.max(-1, Math.min(100, parseInt(v) ?? -1))
    if (n === root.globalBlur) return
    root.globalBlur = n
    root.save()
  }
  property var widgets: []
  property var byId: ({})
  property var enabledIds: []
  property var allIds: []
  property bool editMode: false
  property bool loaded: false
  property string lastWritten: ""


  signal raiseRequested()

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
        const j = JSON.parse(raw)
        root.layer = (j.layer === "background") ? "background" : "bottom"
        root.widgetsEnabled = j.widgetsEnabled !== false
        root.globalOpacity = Math.max(-1, Math.min(100, parseInt(j.globalOpacity ?? -1) || 0))
        if (j.globalOpacity === undefined || j.globalOpacity === null) root.globalOpacity = -1
        root.globalBlur = Math.max(-1, Math.min(100, parseInt(j.globalBlur ?? -1) || 0))
        if (j.globalBlur === undefined || j.globalBlur === null) root.globalBlur = -1
        root.widgets = (Array.isArray(j.widgets) ? j.widgets : []).map(root.normalize).filter(w => w)
      } else {
        root.widgets = []
      }
    } catch (e) {
      console.log("[widgets] widgets.json inválido, lo ignoro:", e)
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
    onLoadFailed: { root.loaded = true; root.rebuild() }
  }

  // ─── Escritura (con retardo: arrastrar no escribe en cada píxel) ───
  function serialize() {
    return JSON.stringify({ version: 1, layer: root.layer, widgetsEnabled: root.widgetsEnabled,
      globalOpacity: root.globalOpacity, globalBlur: root.globalBlur, widgets: root.widgets }, null, 2)
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
      'mkdir -p "$OOZE_DIR" && printf %s "$OOZE_JSON" > "$OOZE_FILE.tmp" && mv "$OOZE_FILE.tmp" "$OOZE_FILE"']
    environment: ({ "OOZE_JSON": writer.payload, "OOZE_DIR": Theme.prefsDir, "OOZE_FILE": root.file })
    running: false
    onRunningChanged: {
      if (running || !pending) return
      pending = false
      running = true
    }
  }

  // ─── Operaciones ───────────────────────────────────────────────
  function indexOf(id) { return root.widgets.findIndex(w => w.id === id) }

  function update(id, patch) {
    const i = root.indexOf(id)
    if (i < 0) return false
    const arr = root.widgets.slice()
    arr[i] = Object.assign({}, arr[i], patch)
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
    const off = 40 * (root.widgets.length % 8)
    root.widgets = root.widgets.concat([{
      id: id, type: type, style: st,
      x: 80 + off, y: 80 + off, w: sz[0], h: sz[1],
      monitor: "", enabled: true, options: Object.assign({}, t.defaults)
    }])
    root.rebuild()
    root.save()
    return id
  }

  function remove(id) {
    if (root.indexOf(id) < 0) return false
    root.widgets = root.widgets.filter(w => w.id !== id)
    root.rebuild()
    root.save()
    return true
  }

  function setStyle(id, style) {
    const i = root.indexOf(id)
    if (i < 0) return false
    const t = WidgetRegistry.get(root.widgets[i].type)
    if (!t || t.styles.indexOf(style) < 0) return false
    const sz = WidgetRegistry.sizeFor(t.id, style)
    return root.update(id, { style: style, w: sz[0], h: sz[1] })
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
