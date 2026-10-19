// CORE — ToggleWallsIpc
// IPC: target="toggleWalls" handle()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "toggleWalls"
    function handle() { self.shell.wallsOpen = !self.shell.wallsOpen }
  }
}
