// CORE — LangIpc
// IPC: target="lang" set(string), get(): string, list(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../Services/Lang"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "lang"
    function set(code: string): void { self.shell.setLang(code) }
    function get(): string { return self.shell.currentLang }
    function togglePicker(): void { self.shell.togglePopup("lang") }
    function list(): string {
      return Translations.availableLanguages.map(l => l.code + " (" + l.name + ")").join(", ")
    }
  }
}
