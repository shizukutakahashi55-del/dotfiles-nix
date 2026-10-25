// CORE — LauncherIpc
// IPC: target="launcher" toggle(), open(string), close()

import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: self
  property var shell
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      if (self.shell.useRofiLauncher()) { self.shell.openRofiLauncher(); return }
      self.shell.launcherStartMode = "apps"
      self.shell.togglePopup("launcher")
    }
    function open(mode: string): void {
      if (self.shell.useRofiLauncher()) { self.shell.openRofiLauncher(); return }
      const ok = ["apps", "run", "files", "commands", "tmux"]
      self.shell.launcherStartMode = ok.indexOf(mode) >= 0 ? mode : "apps"
      self.shell.openPopup("launcher")
    }
    function close(): void { self.shell.launcherOpen = false }
  }
}
