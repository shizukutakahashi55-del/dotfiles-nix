// CORE — CompositorPlatform
// IPC: target="wm" get(): string, set(string): void

pragma Singleton
import Quickshell
import QtQuick
import "../COMMON"

Singleton {
  id: root
  readonly property string wm: {
    try { return WM.wm } catch (e) { return "hyprland" }
  }
  readonly property string detectedWm: {
    try { return WM.detectedWm } catch (e) { return "" }
  }
  readonly property bool isHyprland: root.wm === "hyprland"
  readonly property bool isNiri: root.wm === "niri"
  readonly property bool isMango: root.wm === "mango"

  function has(cap) {
    try { return WM.has(cap) } catch (e) { return false }
  }
  function get(): string {
    return JSON.stringify({ wm: root.wm, detected: root.detectedWm })
  }
  function set(id) {
    try { WM.setWm(id) } catch (e) { ConfigService.setWmPref(id) }
  }
}
