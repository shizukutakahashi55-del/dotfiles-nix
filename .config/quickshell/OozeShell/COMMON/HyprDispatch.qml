// HyprDispatch — enfocar ventanas / ir a workspaces en Hyprland, sea cual
// sea el modo de configuración.
//
// Cada función prueba primero el dispatcher Lua (hl.dsp.focus) y, si
// hyprctl no contesta "ok", cae al dispatcher clásico. 
//
// El argumento viaja como parámetro posicional de `sh -c` ($1), nunca
// pegado dentro del script, y se valida antes (solo direcciones hex y
// números), así no hay forma de inyectar código.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  // Enfoca una ventana por su dirección ("0x55d1…", como la da hyprctl).
  // Si está en otro workspace, Hyprland cambia a él.
  function focusWindow(address) {
    const a = String(address || "")
    if (!/^0x[0-9a-fA-F]+$/.test(a)) return
    Quickshell.execDetached(["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.focus({ window = \\"address:$1\\" })" 2>&1); ' +
      '[ "$out" = "ok" ] || hyprctl dispatch focuswindow "address:$1" >/dev/null 2>&1',
      "sh", a])
  }

  // Va al workspace numerado `id` (Hyprland lo crea si no existe).
  function workspace(id) {
    const n = parseInt(id)
    if (isNaN(n)) return
    Quickshell.execDetached(["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" 2>&1); ' +
      '[ "$out" = "ok" ] || hyprctl dispatch workspace "$1" >/dev/null 2>&1',
      "sh", String(n)])
  }
}
