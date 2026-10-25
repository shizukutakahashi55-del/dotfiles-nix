// CORE — NetworkIpc
// IPC: target="network" toggle()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "network"
    function toggle(): void { self.shell.togglePopup("network") }
  }
}
