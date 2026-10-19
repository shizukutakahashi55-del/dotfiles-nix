// CORE — ThemeIpc
// IPC: target="theme" mode(), toggle(), cycle(), get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "theme"
    function mode(m: string): void { Theme.setThemeMode(m) }
    function toggle(): void { Theme.setThemeMode(Theme.themeMode === "dark" ? "light" : "dark") }
    function cycle(): void {
      const order = ["dark", "light", "colorful"]
      Theme.setThemeMode(order[(order.indexOf(Theme.themeMode) + 1) % order.length])
    }
    function get(): string { return Theme.schemeMode }

    function style(s: string): void { Theme.setUiStyle(s) }
    function styleGet(): string { return Theme.uiStyle }

    function font(name: string): void { Theme.setFontPref(name) }
    function fontGet(): string { return Theme.fontFamily }

    function softfont(name: string): void { Theme.setSoftFont(name) }
    function softfontGet(): string { return Theme.softFamily }
    function pixelfont(name: string): void { Theme.setPixelFont(name) }
    function pixelfontGet(): string { return Theme.pixelFamily }

    function fonts(): string {
      return "texto=" + Theme.fontFamily + " | títulos=" + Theme.titleFamily
        + " | íconos=" + Theme.monoFamily + " | pixel=" + Theme.pixelFamily
        + " | Nunito=" + (Theme.hasFont("Nunito") ? "sí" : "NO")
        + " | M PLUS Rounded 1c=" + (Theme.hasFont("M PLUS Rounded 1c") ? "sí" : "NO")
        + " | rescatadas=" + Theme.rescuedCount + " | " + Theme.fontReport
    }
    function fontsrefresh(): string { Theme.refreshFonts(); return "releyendo fuentes…" }

    function cozy(mode: string): void { Theme.enableCozy(mode === "dark" ? true : mode === "light" ? false : null) }
    function palette(name: string): void { Theme.setPaletteByName(name) }
    function cozywarm(n: int): void { Theme.setCozyWarm(n) }
  }
}
