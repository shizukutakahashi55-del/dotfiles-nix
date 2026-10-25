// visible: !FullscreenState.isOn(targetScreen)
// Solo cuenta fullscreen real: una ventana maximizada NO lo activa. La lógica vive en cada backend (ver WM.hasFullscreen): Hyprland por workspaces, Mango por mmsg; Niri no lo informa por IPC: se deduce del tamaño de la ventana activa del workspace visible (igual al del monitor).

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  function isOn(screen) { return WM.hasFullscreen(screen) }
}
