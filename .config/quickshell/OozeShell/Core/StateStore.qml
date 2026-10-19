// CORE — StateStore
// IPC: target="state" get(): string

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/oozeshell"
  readonly property string stateFile: cacheDir + "/state.json"

  property var common: ({ monitor: "auto", lang: "en", corners: false })
  property var perWm: ({ hyprland: ({}), niri: ({}), mango: ({}) })
  property string wm: "hyprland"
  function setWm(id) {
    if (id === "hyprland" || id === "mango" || id === "niri") root.wm = id
  }
  property bool ready: false
  signal loaded()

  function get(key) {
    const over = root.perWm[root.wm] || {}
    if (over[key] !== undefined) return over[key]
    return root.common[key]
  }
  function set(key, value) {
    const all = Object.assign({}, root.perWm)
    const cur = Object.assign({}, all[root.wm] || {})
    cur[key] = value
    all[root.wm] = cur
    root.perWm = all
    root.save()
  }
  function setCommon(key, value) {
    const c = Object.assign({}, root.common)
    c[key] = value
    root.common = c
    root.save()
  }
  function getState(): string {
    return JSON.stringify({ common: root.common, perWm: root.perWm })
  }

  Component.onCompleted: root.migrateLegacy()
  function migrateLegacy() {
    if (!migrator.running) migrator.running = true
  }
  Process {
    id: migrator
    command: ["sh", "-c",
      'S="$1";' +
      'echo "##STATE##"; cat "$S" 2>/dev/null; echo;' +
      'for f in oozeshell-monitor oozeshell-lang oozeshell-corners oozeshell-appearance.json oozeshell-dnd oozeshell-dock-pins; do' +
      ' echo "##$f##"; cat "$HOME/.cache/$f" 2>/dev/null; echo;' +
      'done',
      "sh", root.stateFile]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => migrator.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const chunks = {}
      let cur = ""
      for (const line of migrator.buffer.split("\n")) {
        if (line.startsWith("##") && line.endsWith("##")) cur = line
        else if (cur !== "") chunks[cur] = (chunks[cur] || "") + line + "\n"
      }
      migrator.buffer = ""
      let hasState = false
      const rawState = (chunks["##STATE##"] || "").trim()
      if (rawState !== "") {
        try {
          const j = JSON.parse(rawState)
          if (j.common) { root.common = Object.assign({}, root.common, j.common); hasState = true }
          if (j.perWm) root.perWm = Object.assign({}, root.perWm, j.perWm)
        } catch (e) { console.log("StateStore: state.json corrupto, uso legacy") }
      }
      root.ready = true
      if (!hasState) {
        const c = Object.assign({}, root.common)
        const mon = (chunks["##oozeshell-monitor##"] || "").trim()
        const lang = (chunks["##oozeshell-lang##"] || "").trim()
        const corners = (chunks["##oozeshell-corners##"] || "").trim()
        const app = (chunks["##oozeshell-appearance.json##"] || "").trim()
        const dnd = (chunks["##oozeshell-dnd##"] || "").trim()
        const pins = (chunks["##oozeshell-dock-pins##"] || "").trim()
        if (mon !== "") c.monitor = mon
        if (lang !== "") c.lang = lang
        if (corners !== "") c.corners = (corners === "1")
        if (app !== "") {
          try { c.appearance = JSON.parse(app) } catch (e) {}
        }
        if (dnd !== "") c.dnd = (dnd === "1")
        if (pins !== "") c.dockPins = pins.split("\n").map(l => l.trim()).filter(l => l !== "")
        root.common = c
        if (mon !== "" || lang !== "" || corners !== "" || app !== "" || dnd !== "" || pins !== "") root.save()
      }
      root.loaded()
    }
  }

  function save() {
    if (!root.ready) return
    saver.json = JSON.stringify({ common: root.common, perWm: root.perWm })
    if (saver.running) saver.pending = true
    else saver.running = true
  }
  Process {
    id: saver
    property string json: ""
    property bool pending: false
    command: ["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$2.tmp" && mv "$2.tmp" "$2"', "sh", root.cacheDir, root.stateFile, saver.json]
    onRunningChanged: {
      if (!running && saver.pending) { saver.pending = false; saver.running = true }
    }
  }
}
