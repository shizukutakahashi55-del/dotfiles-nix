// CORE — AgendaIpc
// IPC: target="agenda" toggle(), open(), close()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "agenda"
    function toggle(): void {
      self.shell.togglePopup("agenda")
    }
    function open(): void {
      self.shell.openPopup("agenda")
    }
    function close(): void {
      if (self.shell.dashboardCalendarOpen) AppState.closeDashboard()
    }
  }
}
