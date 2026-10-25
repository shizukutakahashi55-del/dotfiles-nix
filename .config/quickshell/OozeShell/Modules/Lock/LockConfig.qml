// LockConfig

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"
import "../Widgets"
import "../../Core/Toml.js" as Toml

Singleton {
  id: root

  readonly property string file: Theme.prefsDir + "/lock.toml"
  readonly property string legacyFile: Theme.prefsDir + "/lock.json"

  // ── Esquema ──
  readonly property var schema: ({
    bgBlur:            { kind: "int",  min: 0,  max: 100, def: 45 },
    bgDim:             { kind: "int",  min: 0,  max: 80,  def: 18 },
    clock24h:          { kind: "bool", def: true },
    clockStyle:        { kind: "enum", values: ["classic", "stacked", "mono", "boxed", "analog"], def: "classic" },
    clockScale:        { kind: "int",  min: 60, max: 140, def: 100 },
    showDate:          { kind: "bool", def: true },
    showAvatar:        { kind: "bool", def: true },
    showLayout:        { kind: "bool", def: true },
    showBattery:       { kind: "bool", def: true },
    layout:            { kind: "enum", values: ["center", "stack-left", "stack-right", "split-center", "split-right", "split-left"], def: "center" },
    showPower:         { kind: "bool", def: false },
    widgetsPlacement:  { kind: "enum", values: ["auto", "top", "bottom", "left", "right"], def: "auto" },
    sideWidth:         { kind: "int",  min: 260, max: 460, def: 340 },
    widgetsStyle:      { kind: "enum", values: ["dashboard", "cards"], def: "dashboard" },
    dashScale:         { kind: "int",  min: 60, max: 140, def: 100 },
    weatherEnabled:    { kind: "bool", def: true },
    weatherScale:      { kind: "int",  min: 60, max: 140, def: 100 },
    weatherCity:       { kind: "text", def: "" },
    weatherFahrenheit: { kind: "bool", def: false },
    weatherRefreshMin: { kind: "int",  min: 10, max: 120, def: 30 },
    weatherForecast:   { kind: "bool", def: true },
    weatherStyle:      { kind: "enum", values: ["forecast", "card", "classic"], def: "forecast" },
    weatherDays:       { kind: "int",  min: 3, max: 5, def: 5 },
    weatherTint:       { kind: "bool", def: true },
    mediaEnabled:      { kind: "bool", def: true },
    mediaScale:        { kind: "int",  min: 60, max: 140, def: 100 },
    mediaOnlyPlaying:  { kind: "bool", def: false },
    mediaCover:        { kind: "bool", def: true },
    mediaStyle:        { kind: "enum", values: ["player", "classic"], def: "player" },
    mediaVisualizer:   { kind: "bool", def: true },
    notifMode:         { kind: "enum", values: ["off", "apps", "notifs"], def: "apps" },
    notifMax:          { kind: "int",  min: 1, max: 6, def: 4 },
    notifScale:        { kind: "int",  min: 60, max: 140, def: 100 }
  })

  // ── Valores ──
  property int bgBlur: root.schema.bgBlur.def
  property int bgDim: root.schema.bgDim.def
  property bool clock24h: root.schema.clock24h.def
  property string clockStyle: root.schema.clockStyle.def
  property int clockScale: root.schema.clockScale.def
  property bool showDate: root.schema.showDate.def
  property bool showAvatar: root.schema.showAvatar.def
  property bool showLayout: root.schema.showLayout.def
  property bool showBattery: root.schema.showBattery.def
  property string layout: root.schema.layout.def
  property bool showPower: root.schema.showPower.def
  property string widgetsPlacement: root.schema.widgetsPlacement.def
  property int sideWidth: root.schema.sideWidth.def
  property string widgetsStyle: root.schema.widgetsStyle.def
  property int dashScale: root.schema.dashScale.def
  property bool weatherEnabled: root.schema.weatherEnabled.def
  property int weatherScale: root.schema.weatherScale.def
  property string weatherCity: root.schema.weatherCity.def
  property bool weatherFahrenheit: root.schema.weatherFahrenheit.def
  property int weatherRefreshMin: root.schema.weatherRefreshMin.def
  property bool weatherForecast: root.schema.weatherForecast.def
  property string weatherStyle: root.schema.weatherStyle.def
  property int weatherDays: root.schema.weatherDays.def
  property bool weatherTint: root.schema.weatherTint.def
  property bool mediaEnabled: root.schema.mediaEnabled.def
  property int mediaScale: root.schema.mediaScale.def
  property bool mediaOnlyPlaying: root.schema.mediaOnlyPlaying.def
  property bool mediaCover: root.schema.mediaCover.def
  property string mediaStyle: root.schema.mediaStyle.def
  property bool mediaVisualizer: root.schema.mediaVisualizer.def
  property string notifMode: root.schema.notifMode.def
  property int notifMax: root.schema.notifMax.def
  property int notifScale: root.schema.notifScale.def

  property bool loaded: false
  property string lastWritten: ""

  // ── Ciudad efectiva ──
  readonly property string widgetCity: {
    for (const w of WidgetConfig.widgets) {
      const c = (w && w.options) ? String(w.options.city ?? "").trim() : ""
      if (c !== "") return c
    }
    return ""
  }
  readonly property string city: root.weatherCity !== "" ? root.weatherCity : root.widgetCity
  readonly property bool cityFromWidget: root.weatherCity === "" && root.widgetCity !== ""

  // ── Validación ──
  function clean(key, v) {
    const s = root.schema[key]
    if (!s) return undefined
    if (s.kind === "bool") {
      if (typeof v === "string") return v === "true" || v === "1" || v === "on"
      return !!v
    }
    if (s.kind === "int") {
      const n = Math.round(Number(v))
      if (isNaN(n)) return undefined
      return Math.max(s.min, Math.min(s.max, n))
    }
    if (s.kind === "enum") return s.values.indexOf(v) >= 0 ? v : undefined
    return String(v ?? "").trim()
  }

  // ── Escritura de valores ──
  function setValue(key, v) {
    const c = root.clean(key, v)
    if (c === undefined) return false
    if (root[key] === c) return true
    root[key] = c
    root.save()
    return true
  }

  function reset() {
    for (const k in root.schema) root[k] = root.schema[k].def
    root.save()
  }

  function dump() {
    const o = {}
    for (const k in root.schema) o[k] = root[k]
    return JSON.stringify(o)
  }

  // ── Lectura ──
  function load(text) {
    const raw = (text || "").trim()
    if (raw !== "" && raw === root.lastWritten) { root.loaded = true; return }
    if (raw !== "") {
      try {
        const j = Toml.parseAny(raw)
        for (const k in root.schema) {
          if (j[k] === undefined) continue
          const c = root.clean(k, j[k])
          if (c !== undefined) root[k] = c
        }
      } catch (e) {
        console.log("[lock] lock.toml inválido, lo ignoro:", e)
      }
    }
    root.loaded = true
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
    onLoadFailed: root.loaded = true
  }

  // ── Escritura en disco ──
  function save() { saveTimer.restart() }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: {
      const o = JSON.parse(root.dump())
      o.version = 1
      const text = Toml.stringify(o)
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
}
