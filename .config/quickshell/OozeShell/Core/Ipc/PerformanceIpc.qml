// CORE — PerformanceIpc
// IPC: target="performance" toggle(), set(bool), get(): bool, getScope(): string, setScope(string)

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "performance"
    function toggle(): void { Theme.setPerformanceMode(!Theme.performanceMode) }
    function set(on: bool): void { Theme.setPerformanceMode(on) }
    function get(): bool { return Theme.performanceMode }
    function getScope(): string { return Theme.performanceScope }
    function setScope(scope: string): void { Theme.setPerformanceScope(scope) }
  }
}
