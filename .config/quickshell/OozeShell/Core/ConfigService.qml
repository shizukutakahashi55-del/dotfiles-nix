// CORE — ConfigService
// IPC: target="config" get(): string

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root
  readonly property string configDir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string configFile: configDir + "/config.json"
  readonly property string legacyFile: configDir + "/wm.json"

  property var config: ({ wmPref: "auto", distroPref: "auto", pkgHelperPref: "auto" })
  property bool ready: false
  signal loaded()

  function get(): string { return JSON.stringify(root.config) }

  Component.onCompleted: { if (!loader.running) loader.running = true }
  Process {
    id: loader
    command: ["sh", "-c", 'cat "$1" 2>/dev/null; echo "##LEGACY##"; cat "$2" 2>/dev/null; echo', "sh", root.configFile, root.legacyFile]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => loader.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const idx = loader.buffer.indexOf("##LEGACY##")
      const main = (idx >= 0 ? loader.buffer.slice(0, idx) : loader.buffer).trim()
      const leg = (idx >= 0 ? loader.buffer.slice(idx + 10) : "").trim()
      loader.buffer = ""
      let found = false
      if (main !== "") {
        try {
          const j = JSON.parse(main)
          if (j && typeof j === "object") { root.config = Object.assign({}, root.config, j); found = true }
        } catch (e) { console.log("ConfigService: config.json corrupto, uso legacy") }
      }
      if (!found && leg !== "") {
        try {
          const j = JSON.parse(leg)
          if (j && typeof j === "object") {
            const c = Object.assign({}, root.config)
            if (j.wm === "auto" || j.wm === "hyprland" || j.wm === "mango" || j.wm === "niri") c.wmPref = j.wm
            if (j.distro) c.distroPref = j.distro
            if (j.pkgHelper) c.pkgHelperPref = j.pkgHelper
            root.config = c
            root.save()
          }
        } catch (e) {}
      }
      root.ready = true
      root.loaded()
    }
  }

  function set(key, value) {
    const c = Object.assign({}, root.config)
    c[key] = value
    root.config = c
    root.save()
  }
  function setWmPref(id) {
    if (id !== "auto" && ["hyprland", "mango", "niri"].indexOf(id) < 0) return
    root.set("wmPref", id)
  }

  function save() {
    if (!root.ready) return
    saver.json = JSON.stringify(root.config)
    if (saver.running) saver.pending = true
    else saver.running = true
  }
  Process {
    id: saver
    property string json: ""
    property bool pending: false
    command: ["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$2.tmp" && mv "$2.tmp" "$2"', "sh", root.configDir, root.configFile, saver.json]
    onRunningChanged: {
      if (!running && saver.pending) { saver.pending = false; saver.running = true }
    }
  }
}
