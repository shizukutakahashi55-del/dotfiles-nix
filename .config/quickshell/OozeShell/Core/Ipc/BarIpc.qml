// CORE — BarIpc
// IPC: target="bar" position(), togglePosition(), floating(), get(): string

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Item {
  id: self
  property var shell
  IpcHandler {
    target: "bar"
    function position(p: string): void { Theme.setBarPosition(p) }
    function togglePosition(): void {
      const flip = { top: "bottom", bottom: "top", left: "right", right: "left" }
      Theme.setBarPosition(flip[Theme.barPosition] ?? "top")
    }
    function floating(on: bool): void { Theme.setBarFloating(on) }
    function toggleFloating(): void { Theme.setBarFloating(!Theme.barFloatingPref) }

    function floatWindows(on: bool): void { Theme.setFloatWindows(on) }
    function toggleFloatWindows(): void { Theme.setFloatWindows(!Theme.floatWindowsPref) }
    function windowAnim(style: string): void { Theme.setWindowAnimStyle(style) }
    function cycleWindowAnim(): void {
      const list = Theme.windowAnimStyles
      Theme.setWindowAnimStyle(list[(list.indexOf(Theme.windowAnimStyle) + 1) % list.length])
    }

    function hidden(on: bool): void { Theme.setBarHidden(on) }
    function toggleHidden(): void { Theme.setBarHidden(!Theme.barHiddenPref) }
    function hiddenFrame(on: bool): void { Theme.setBarHiddenFrame(on) }
    function revealMode(mode: string): void { Theme.setBarRevealMode(mode) }
    function peek(): void { Theme.requestBarPeek("click") }

    function templateSave(name: string): bool { return Theme.saveBarTemplate(name) }
    function templateLoad(name: string): bool { return Theme.loadBarTemplate(name) }
    function templateDelete(name: string): bool { return Theme.deleteBarTemplate(name) }
    function templates(): string { return JSON.stringify(Theme.barBuiltinNames.concat(Theme.barTemplateNames)) }
    function islands(on: bool): void { Theme.setIslandsEnabled(on) }
    function toggleIslands(): void { Theme.setIslandsEnabled(!Theme.islandsPref) }
    function pill(on: bool): void { Theme.setPillModeEnabled(on) }
    function togglePill(): void { Theme.setPillModeEnabled(!Theme.pillModePref) }
    function get(): string {
      return JSON.stringify({ position: Theme.barPosition, floating: Theme.barFloatingPref,
                              islands: Theme.islandsPref, pill: Theme.pillModePref,
                              floatWindows: Theme.floatWindowsPref, windowAnim: Theme.windowAnimStyle,
                              hidden: Theme.barHiddenPref, hiddenFrame: Theme.barHiddenFramePref, revealMode: Theme.barRevealMode })
    }
  }
}
