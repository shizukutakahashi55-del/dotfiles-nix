// PrivacyBackend — ¿qué apps están usando tu pantalla o tu micrófono?
// (reemplaza el módulo "privacy" de Waybar)

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root


  property var ignoreApps: ["cava", "pavucontrol", "pulseaudio volume control"]

  property var screenApps: []
  property var micApps: []
  readonly property bool screenshare: screenApps.length > 0
  readonly property bool micActive: micApps.length > 0


  PwObjectTracker { objects: Pipewire.nodes.values }

  function prop(node, key) {
    const p = node.properties
    return (p && p[key] !== undefined) ? String(p[key]) : ""
  }

  function labelOf(node) {
    return prop(node, "application.name")
        || prop(node, "node.description")
        || node.description
        || node.name
        || "?"
  }

  function ignored(name) {
    return root.ignoreApps.indexOf(name.toLowerCase()) !== -1
  }


  function pushUnique(arr, name) {
    if (arr.indexOf(name) === -1) arr.push(name)
  }

  function scan() {
    const screen = []
    const mic = []
    const nodes = Pipewire.nodes.values

    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!n) continue

      const cls = root.prop(n, "media.class")
      if (cls !== "Stream/Input/Video" && cls !== "Stream/Input/Audio") continue

      const name = root.labelOf(n)
      if (root.ignored(name)) continue

      if (cls === "Stream/Input/Video") {
        if (root.prop(n, "media.role") === "Camera") continue
        root.pushUnique(screen, name)
      } else {
        if (root.prop(n, "stream.capture.sink") === "true") continue
        root.pushUnique(mic, name)
      }
    }


    if (JSON.stringify(screen) !== JSON.stringify(root.screenApps)) root.screenApps = screen
    if (JSON.stringify(mic) !== JSON.stringify(root.micApps)) root.micApps = mic
  }


  Connections {
    target: Pipewire.nodes
    function onValuesChanged() { root.scan() }
  }


  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.scan()
  }
}
