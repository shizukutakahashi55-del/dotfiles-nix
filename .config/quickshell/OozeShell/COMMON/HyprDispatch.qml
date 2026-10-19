// HyprDispatch — enfocar ventanas / ir a workspaces en Hyprland, sea cual sea el modo de configuración.

pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root


  function focusWindow(address) {
    const a = String(address || "")
    if (!/^0x[0-9a-fA-F]+$/.test(a)) return
    Quickshell.execDetached(["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.focus({ window = \\"address:$1\\" })" 2>&1); ' +
      '[ "$out" = "ok" ] || hyprctl dispatch focuswindow "address:$1" >/dev/null 2>&1',
      "sh", a])
  }


  function workspace(id) {
    const n = parseInt(id)
    if (isNaN(n)) return
    Quickshell.execDetached(["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" 2>&1); ' +
      '[ "$out" = "ok" ] || hyprctl dispatch workspace "$1" >/dev/null 2>&1',
      "sh", String(n)])
  }
}
