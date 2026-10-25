// CORE — CaffeineIpc
// IPC: target="caffeine" toggle(), set(bool), get(): bool

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Caffeine"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "caffeine"
    function toggle(): void { CaffeineBackend.toggle(); self.shell.caffeineToast() }
    function set(on: bool): void { CaffeineBackend.set(on); self.shell.caffeineToast() }
    function get(): bool { return CaffeineBackend.active }
  }
}
