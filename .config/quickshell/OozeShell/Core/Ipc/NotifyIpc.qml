// CORE — NotifyIpc
// IPC: target="notify" toggle(), show(string), state(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Notify"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "notify"
    function toggle(): void { self.shell.togglePopup("notify") }

    function show(text: string): void { NotificationsBackend.pushLocal("OozeShell", text) }
    function toggleDnd(): void { NotificationsBackend.toggleDnd() }
    function enableDnd(): void { NotificationsBackend.dnd = true }
    function disableDnd(): void { NotificationsBackend.dnd = false }
    function isDnd(): bool { return NotificationsBackend.dnd }
    function clear(): void { NotificationsBackend.clearAll() }
    function state(): string {
      return JSON.stringify({ count: NotificationsBackend.count, dnd: NotificationsBackend.dnd })
    }
  }
}
