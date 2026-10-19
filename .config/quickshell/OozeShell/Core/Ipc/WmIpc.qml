// CORE — WmIpc
// IPC: target="wm" get(): string, set(string): void

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Core"

Item {
  id: self
  property var shell

  IpcHandler {
    target: "wm"
    function get(): string { return CompositorPlatform.get() }
    function set(id: string): void { CompositorPlatform.set(id) }
  }
}
