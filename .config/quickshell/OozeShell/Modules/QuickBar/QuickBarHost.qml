// QuickBarHost — QuickSearch lista para colgar en shell.qml: estado abierto/cerrado, montaje perezoso y el IPC propio (`quickbar …`).

import Quickshell
import Quickshell.Io
import QtQuick
import "../../COMMON"

Scope {
  id: host

  // ─── IPC ───

  IpcHandler {
    target: "quickbar"
    function toggle(): void { host.toggle() }
    function open(): void { host.open() }
    function close(): void { host.close() }
    function search(text: string): void { host.openWith(text) }

    function files(): void { host.openWith("f ") }
    function position(p: string): void { QuickBarConfig.set("position", p) }
    function filesEnabled(on: bool): void { QuickBarConfig.set("filesEnabled", on) }
    function get(): string { return JSON.stringify(QuickBarConfig.snapshot()) }
  }

  property bool opened: false
  property string targetScreen: ""
  property string startQuery: ""


  property var resolveScreen: null

  signal aboutToOpen()

  function openWith(query) {
    host.startQuery = query
    host.aboutToOpen()
    if (typeof host.resolveScreen === "function") host.targetScreen = host.resolveScreen()
    host.opened = true
  }
  function open() { host.openWith("") }
  function close() { host.opened = false }
  function toggle() {
    if (host.opened) host.close()
    else host.open()
  }


  LazyPopup {
    id: gate
    wanted: host.opened
    openDelay: 50
    QuickBar {
      open: gate.open
      targetScreen: host.targetScreen
      startQuery: host.startQuery
      onCloseRequested: host.opened = false
    }
  }
}
