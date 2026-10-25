// CORE — ScreenshotIpc
// IPC: target="screenshot" areaCopy(), fullSave(), areaSave()

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Screenshot"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "screenshot"
    function areaCopy(): void { ScreenshotBackend.areaCopy() }
    function fullSave(): void { ScreenshotBackend.fullSave() }
    function areaSave(): void { ScreenshotBackend.areaSave() }
  }
}
