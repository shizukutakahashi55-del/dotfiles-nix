import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Equalizer"

Item {
  id: self
  property var shell
  readonly property bool ready: EqualizerService.loaded
  IpcHandler {
    target: "equalizer"
    function toggle(): void { EqualizerService.toggleWindow(self.shell.resolveMonitor()) }
    function open(): void { EqualizerService.openWindow(self.shell.resolveMonitor()) }
    function close(): void { EqualizerService.closeWindow() }
    function enable(): void { EqualizerService.setEnabled(true) }
    function disable(): void { EqualizerService.setEnabled(false) }
    function switchState(): void { EqualizerService.toggleEnabled() }
    function preset(name: string): void { EqualizerService.setPreset(name) }
    function reset(): void { EqualizerService.reset() }
  }
}
