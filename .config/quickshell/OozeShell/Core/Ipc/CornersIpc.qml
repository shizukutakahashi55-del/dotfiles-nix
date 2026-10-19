// CORE — CornersIpc
// IPC: target="corners" toggle(), set(bool), get(): bool

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "corners"
    function toggle(): void { self.shell.setScreenCorners(!self.shell.screenCorners) }
    function set(on: bool): void { self.shell.setScreenCorners(on) }
    function get(): bool { return self.shell.screenCorners }
  }
}
