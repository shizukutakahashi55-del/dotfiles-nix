// CORE — SystemMonitorIpc
// IPC: target="sysmon" open(section), close(), toggle(), section(name), isOpen(): bool, backend(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"
import "../../Backends"

Item {
  id: self
  property var shell

  IpcHandler {
    target: "sysmon"
    function open(section: string): void {
      AppState.openSystemMonitor(section || "overview", self.shell ? self.shell.resolveMonitor() : "")
    }
    function close(): void { AppState.closeSystemMonitor() }
    function toggle(): void {
      AppState.toggleSystemMonitor("", self.shell ? self.shell.resolveMonitor() : "")
    }
    function section(name: string): void {
      if (AppState.sysMonOpen) AppState.sysMonSection = name
    }
    function isOpen(): bool { return AppState.sysMonOpen }
    function backend(): string { return SystemMonitor.backend + "/" + ProcessList.backend }
  }
}
