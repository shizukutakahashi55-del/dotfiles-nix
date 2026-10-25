// CORE — CapsIpc
// IPC: target="caps" show(bool)

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  property var capsOsd
  IpcHandler {
    target: "caps"
    function show(on: bool): void { self.capsOsd.show(on) }
  }
}
