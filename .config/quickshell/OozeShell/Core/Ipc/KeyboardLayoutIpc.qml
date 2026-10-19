// CORE — KeyboardLayoutIpc
// IPC: target="keyboardlayout" next()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "keyboardlayout"
    function next(): void { KeyboardLayout.next() }
  }
}
