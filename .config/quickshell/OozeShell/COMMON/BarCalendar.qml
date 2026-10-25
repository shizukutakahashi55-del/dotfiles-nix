// BarCalendar — estado compartido del calendario que cuelga del reloj de la barra.

pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property string screenName: ""
  property string side: "center"
  property real anchor: 0
  property bool clockHover: false

  function isOpen(screen) { return root.screenName !== "" && root.screenName === screen }

  function show(screen, side, anchor) {
    root.side = side
    root.anchor = anchor
    root.screenName = screen
  }

  function hide() { root.screenName = "" }

  function toggle(screen, side, anchor) {
    if (root.isOpen(screen)) root.hide()
    else root.show(screen, side, anchor)
  }
}
