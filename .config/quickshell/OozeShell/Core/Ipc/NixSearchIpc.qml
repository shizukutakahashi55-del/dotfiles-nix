// CORE — NixSearchIpc
// IPC: target="nixsearch" toggle(), open(string), installed(), close()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "nixsearch"
    function toggle(): void {
      self.shell.nixStartQuery = ""
      self.shell.nixStartInstalled = false
      self.shell.togglePopup("nixsearch")
    }
    function open(query: string): void {
      self.shell.nixStartQuery = query
      self.shell.nixStartInstalled = false
      self.shell.openPopup("nixsearch")
    }

    function installed(): void {
      self.shell.nixStartQuery = ""
      self.shell.nixStartInstalled = true
      self.shell.openPopup("nixsearch")
    }
    function close(): void { self.shell.nixSearchOpen = false }
  }
}
