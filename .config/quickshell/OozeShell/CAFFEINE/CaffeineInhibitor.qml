// CaffeineInhibitor — ventana mínima invisible que sostiene el IdleInhibitor de Wayland mientras Caffeine está activo.

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
  LazyLoader {
    active: CaffeineBackend.active

    PanelWindow {
      id: win
      implicitWidth: 1
      implicitHeight: 1
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "ooze-caffeine"
      mask: Region {}

      IdleInhibitor {
        window: win
        enabled: CaffeineBackend.active
      }
    }
  }
}
