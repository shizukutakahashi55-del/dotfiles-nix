// CORE — StateIpc
// IPC: target="state" get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Core"

Item {
  id: self
  property var shell

  IpcHandler {
    target: "state"
    function get(): string { return StateStore.getState() }
  }
}
