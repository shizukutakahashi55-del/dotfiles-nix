// CORE — MonitorIpc
// IPC: target="monitor" set(string), get(): string, list(): string, current(): string

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "monitor"
    function set(name: string): void { self.shell.setMonitor(name) }
    function get(): string { return self.shell.targetMonitor }
    function togglePicker(): void { self.shell.togglePopup("monitor") }
    function list(): string {
      return Quickshell.screens.map(s => s.name).join(", ")
    }
    function current(): string { return self.shell.resolveMonitor() }
  }
}
