// Uso (dentro de un binding, se re-evalúa solo):
//   visible: !FullscreenState.isOn(targetScreen)
//
// "hasfullscreen" sale de `hyprctl workspaces -j`. Solo cuenta fullscreen
// real: una ventana maximizada NO lo activa.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
  id: root

  function isOn(screen) {
    if (!screen) return false
    const mon = Hyprland.monitorFor(screen)
    const ws = mon ? mon.activeWorkspace : null
    const o = ws ? ws.lastIpcObject : null
    return o ? o.hasfullscreen === true : false
  }

  // lastIpcObject solo se actualiza al refrescar: lo pedimos cuando pasa algo
  // que pueda cambiar el fullscreen. El Timer junta ráfagas en una consulta.
  Timer {
    id: refreshTimer
    interval: 40
    repeat: false
    onTriggered: Hyprland.refreshWorkspaces()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      switch (event.name) {
        case "fullscreen":
        case "workspace":
        case "workspacev2":
        case "focusedmon":
        case "focusedmonv2":
        case "activewindow":
        case "closewindow":
        case "openwindow":
        case "movewindow":
        case "movewindowv2":
          refreshTimer.restart()
          break
      }
    }
  }

  Component.onCompleted: Hyprland.refreshWorkspaces()
}
