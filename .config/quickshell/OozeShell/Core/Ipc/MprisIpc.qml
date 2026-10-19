// CORE — MprisIpc
// IPC: target="mpris" toggle()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "mpris"
    function toggle() {
      if (Theme.pillMode) AppState.toggleDashboard("mpris", self.shell.focusedMonitor)
      else self.shell.togglePopup("mpris")
    }
  }
}
