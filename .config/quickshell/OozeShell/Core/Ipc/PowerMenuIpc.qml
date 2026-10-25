// CORE — PowerMenuIpc
// IPC: target="powermenu" toggle(), open(), close()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "powermenu"
    function toggle(): void {
      if (Theme.pillMode) { AppState.toggleDashboard("power", self.shell.focusedMonitor); return }
      if (self.shell.useRofiPower()) { self.shell.openRofiPower(); return }
      self.shell.closeAllPopups()
      if (!self.shell.powerOpen) self.shell.focusedMonitor = self.shell.resolveMonitor()
      self.shell.powerOpen = !self.shell.powerOpen
    }
    function open(): void {
      if (Theme.pillMode) { AppState.openDashboard("power", self.shell.focusedMonitor); return }
      if (self.shell.useRofiPower()) { self.shell.openRofiPower(); return }
      self.shell.closeAllPopups()
      self.shell.focusedMonitor = self.shell.resolveMonitor()
      self.shell.powerOpen = true
    }
    function close(): void { self.shell.powerOpen = false }
  }
}
