// CORE — LayoutOsdIpc
// IPC: target="layoutosd" show(string)

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  property var layoutOsd
  IpcHandler {
    target: "layoutosd"
    function show(name: string): void { self.layoutOsd.show(name, KeyboardLayout.labelFor(name)) }
  }
}
