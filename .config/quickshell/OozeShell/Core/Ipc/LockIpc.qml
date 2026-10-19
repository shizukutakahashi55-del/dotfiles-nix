// CORE — LockIpc
// IPC: target="lock" lock(), locked(): bool, get(): string, set(key, value): bool, reset()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Modules/Lock"

Item {
  id: self
  property var shell
  property var lockScreen
  IpcHandler {
    target: "lock"
    function lock(): void {
      self.shell.closeAllPopups()
      self.shell.powerOpen = false
      self.shell.wallsOpen = false
      self.lockScreen.lock()
    }
    function locked(): bool { return self.lockScreen.locked }
    function get(): string { return LockConfig.dump() }
    function set(key: string, value: string): bool { return LockConfig.setValue(key, value) }
    function reset(): void { LockConfig.reset() }
  }
}
