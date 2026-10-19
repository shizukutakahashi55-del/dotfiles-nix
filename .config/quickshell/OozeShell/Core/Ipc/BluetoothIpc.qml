// CORE — BluetoothIpc
// IPC: target="bluetooth" toggle()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "bluetooth"
    function toggle(): void { self.shell.togglePopup("bluetooth") }
  }
}
