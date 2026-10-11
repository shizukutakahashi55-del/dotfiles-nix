// TaskbarMenu — drop con la lista de ventanas, como popup de la barra.
// (En Píldora no se usa: la píldora se transforma en la lista, ver PILL/Pill.qml.)

import Quickshell
import QtQuick
import "../COMMON"
import "../LANG"

Item {
  id: root

  property bool open: false
  property var windows: []


  property real anchorX: 0
  property real anchorY: 0
  property string targetScreen: ""
  signal closeRequested()

  property int menuWidth: 260

  property int maxListHeight: 420
  property int edgeMargin: 10

  FusedWindow {
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-taskbar"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open && root.windows.length > 0
      panelWidth: root.menuWidth
      contentHeight: list.implicitHeight


      align: "center"
      alignMargin: root.edgeMargin
      alignCenter: Theme.barVertical ? root.anchorY : root.anchorX


      Behavior on x {
        enabled: panel.shown && !Theme.barVertical && !panel.hull
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }
      Behavior on y {
        enabled: panel.shown && Theme.barVertical
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }

      TaskbarList {
        id: list
        x: 0
        y: 0
        width: parent.width
        windows: root.windows
        maxListHeight: root.maxListHeight
        onCloseRequested: root.closeRequested()
      }
    }
  }
}
