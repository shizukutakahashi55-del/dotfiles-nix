// FullscreenState — ¿hay una ventana en fullscreen real en esa pantalla?
//
// Uso (dentro de un binding, se re-evalua solo):
//   visible: !FullscreenState.isOn(targetScreen)
//
// Sale de `mmsg watch all-clients` (MangoIpc). Solo cuenta fullscreen real:
// una ventana maximizada o fakefullscreen NO lo activa.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  function isOn(screen) {
    if (!screen) return false
    return MangoIpc.hasFullscreen(screen.name)
  }
}
