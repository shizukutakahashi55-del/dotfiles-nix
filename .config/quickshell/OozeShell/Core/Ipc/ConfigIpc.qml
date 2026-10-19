// CORE — ConfigIpc
// IPC: target="config" get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Core"

Item {
  id: self
  property var shell

  IpcHandler {
    target: "config"
    function get(): string { return ConfigService.get() }
  }
}
