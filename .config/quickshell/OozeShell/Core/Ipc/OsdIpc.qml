// CORE — OsdIpc
// IPC: target="osd" show(string, string, string, bool)

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  property var toastOsd
  IpcHandler {
    target: "osd"
    function show(icon: string, title: string, subtitle: string, active: bool): void {
      self.toastOsd.show(icon, title, subtitle, active)
    }
  }
}
