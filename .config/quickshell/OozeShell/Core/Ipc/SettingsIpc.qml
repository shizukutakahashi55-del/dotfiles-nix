// CORE — SettingsIpc
// IPC: target="settings" toggle(), open(), close(), get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "settings"
    function toggle(): void { self.shell.togglePopup("advancedsettings") }
    function open(): void { self.shell.openPopup("advancedsettings") }
    function close(): void { self.shell.advancedSettingsOpen = false }
    function get(): string {
      return JSON.stringify({ font: Theme.fontLevel, bar: Theme.barLevel, window: Theme.windowLevel,
                              settingsSize: Theme.settingsSizeSpec.id, dock: Theme.settingsDockMode })
    }
    function dock(mode: string): void {
      if (mode === "toggle") Theme.setSettingsSideMode(!Theme.settingsSideMode)
      else if (mode === "swap") Theme.toggleSettingsSide()
      else Theme.setSettingsDockMode(mode)
    }
    function setUi(level: int): void { Theme.setInterfaceLevel(level) }
    function setLevel(kind: string, level: int): void { Theme.setLevel(kind, level) }
    function reset(): void { Theme.resetLevels() }
    function setSize(level: int): void { Theme.setSettingsSize(level) }
    function resetWindow(): void { Theme.resetSettingsWin() }
  }
}
