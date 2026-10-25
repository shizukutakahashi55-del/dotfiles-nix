// CORE — ConfigService
// IPC: target="config" get(): string

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "Toml.js" as Toml

Singleton {
  id: root
  readonly property string configDir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string configFile: configDir + "/config.toml"
  readonly property string legacyJson: configDir + "/config.json"
  readonly property string legacyFile: configDir + "/wm.json"

  property var config: ({ wmPref: "auto", distroPref: "auto", pkgHelperPref: "auto" })
  property bool ready: false
  signal loaded()

  function get(): string { return JSON.stringify(root.config) }

  Component.onCompleted: { if (!loader.running) loader.running = true }
  Process {
    id: loader
    command: ["sh", "-c", 'cat "$1" 2>/dev/null; echo "##JSON##"; cat "$2" 2>/dev/null; echo "##LEGACY##"; cat "$3" 2>/dev/null; echo', "sh", root.configFile, root.legacyJson, root.legacyFile]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => loader.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const b = loader.buffer
      loader.buffer = ""
      const iJson = b.indexOf("##JSON##")
      const iLeg = b.indexOf("##LEGACY##")
      const main = (iJson >= 0 ? b.slice(0, iJson) : b).trim()
      const js = (iJson >= 0 ? b.slice(iJson + 8, iLeg >= 0 ? iLeg : b.length) : "").trim()
      const leg = (iLeg >= 0 ? b.slice(iLeg + 10) : "").trim()
      let found = false
      let migrated = false
      if (main !== "") {
        try {
          const j = Toml.parseAny(main)
          if (j && typeof j === "object") { root.config = Object.assign({}, root.config, j); found = true }
        } catch (e) { console.log("ConfigService: config.toml corrupto, uso legacy") }
      }
      if (!found && js !== "") {
        try {
          const j = JSON.parse(js)
          if (j && typeof j === "object") { root.config = Object.assign({}, root.config, j); found = true; migrated = true }
        } catch (e) { console.log("ConfigService: config.json corrupto") }
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
            migrated = true
          }
        } catch (e) {}
      }
      root.ready = true
      if (migrated) root.save()
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
    saver.text = Toml.stringify(root.config)
    if (saver.running) saver.pending = true
    else saver.running = true
  }
  Process {
    id: saver
    property string text: ""
    property bool pending: false
    command: ["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$2.tmp" && mv "$2.tmp" "$2" && for f in "$4" "$5"; do [ -f "$f" ] && mv -f "$f" "$f.bak"; done; true', "sh", root.configDir, root.configFile, saver.text, root.legacyJson, root.legacyFile]
    onRunningChanged: {
      if (!running && saver.pending) { saver.pending = false; saver.running = true }
    }
  }
}
