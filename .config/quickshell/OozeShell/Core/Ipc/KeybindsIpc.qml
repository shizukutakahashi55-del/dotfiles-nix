// CORE — KeybindsIpc
// IPC: target="keybinds" toggle()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "keybinds"
    function toggle(): void { self.shell.togglePopup("keybinds") }
  }
}
