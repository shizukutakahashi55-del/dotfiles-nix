// CORE — MenuIpc
// IPC: target="menu" toggle()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "menu"
    function toggle(): void {
      if (Theme.pillMode) AppState.toggleDashboard("quickaccess", self.shell.focusedMonitor)
      else self.shell.togglePopup("menu")
    }
  }
}
