// CORE — OverviewIpc
// IPC: target="overview" toggle(), open(), close()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "overview"
    function toggle(): void {
      if (WM.hasNativeOverview) { WM.toggleNativeOverview(); return }
      self.shell.togglePopup("overview")
    }
    function open(): void {
      if (WM.hasNativeOverview) { WM.openNativeOverview(); return }
      self.shell.openPopup("overview")
    }
    function close(): void {
      if (WM.hasNativeOverview) WM.closeNativeOverview()
      else self.shell.overviewOpen = false
    }
  }
}
