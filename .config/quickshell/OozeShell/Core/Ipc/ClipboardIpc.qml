// CORE — ClipboardIpc
// IPC: target="clipboard" toggle(), open(), close()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  property var history
  IpcHandler {
    target: "clipboard"
    function toggle(): void { self.history.toggle() }
    function open(): void { self.history.open() }
    function close(): void { self.history.close() }
  }
}
