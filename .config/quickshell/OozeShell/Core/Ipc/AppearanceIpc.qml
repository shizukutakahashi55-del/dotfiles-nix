// CORE — AppearanceIpc
// IPC: target="appearance" toggle(), get(): string, set(string, string)

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "appearance"
    function toggle(): void { self.shell.togglePopup("appearance") }
    function get(): string { return JSON.stringify(self.shell.appearance) }

    function set(key: string, value: string): void {
      if (key === "layout") { self.shell.setLayout(value); return }
      if (key === "animProfile") { self.shell.setAnimProfile(value); return }
      if (key === "blurEnabled" || key === "blurOptimized" || key === "animationsEnabled" || key === "shadowEnabled") {
        self.shell.setAppearanceValue(key, (value === "true" || value === "1"))
      } else {
        self.shell.setAppearanceValue(key, parseFloat(value))
      }
    }
  }
}
