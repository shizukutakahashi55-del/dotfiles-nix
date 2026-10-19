// CORE — NativeIpc
// IPC: target="native" get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Backends/native"

Item {
  id: self
  property var shell

  IpcHandler {
    target: "native"
    function get(): string { return NativeSpec.get() }
  }
}
