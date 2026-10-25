// DockBackend — apps "fijadas" al dock (favoritas): quedan como lanzadores aunque se cierren. Se fijan/desfijan con clic derecho sobre

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Core"

Singleton {
  id: root

  property var pinnedApps: []

  Connections {
    target: StateStore
    function onLoaded() { root.applyStoredPins() }
  }
  Component.onCompleted: { if (StateStore.ready) root.applyStoredPins() }
  function applyStoredPins() {
    const v = StateStore.get("dockPins")
    if (Array.isArray(v)) root.pinnedApps = v
  }

  function isPinned(appId) {
    return appId !== "" && root.pinnedApps.indexOf(appId) >= 0
  }

  function togglePin(appId) {
    if (!appId || appId === "") return
    const list = root.pinnedApps.slice()
    const i = list.indexOf(appId)
    if (i >= 0) list.splice(i, 1)
    else list.push(appId)
    root.pinnedApps = list
    root.save()
  }

  function save() {
    StateStore.setCommon("dockPins", root.pinnedApps)
  }
}
