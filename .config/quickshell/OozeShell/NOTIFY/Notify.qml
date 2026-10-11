// Notify — centro de notificaciones nativo de OozeShell (estructura swaync):

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../COMMON"
import "../LANG"
import "../NOTIFY"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()

  property int cardWidth: 400
  property int edgeMargin: 10
  readonly property int pad: 16


  readonly property bool panelOn: !Theme.pillMode

  readonly property real maxListHeight: Math.max(160, (fw.screenHeight - (Theme.barVertical ? 0 : Theme.barFace)) / Theme.windowScale - 280)


  onOpenChanged: NotificationsBackend.centerOpen = root.open

  FusedWindow {
    id: fw
    active: root.panelOn && (root.open || panel.shown)
    targetScreen: root.targetScreen
    namespace: "oozeshell-notifications"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open && root.panelOn
      panelWidth: root.cardWidth
      contentHeight: list.implicitHeight


      snapResize: true


      align: "center"
      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm

      NotifList {
        id: list
        x: 0
        y: 0
        width: parent.width
        maxListHeight: root.maxListHeight
        listActive: root.open || panel.shown
        entriesAnimated: panel.open && panel.progress >= 0.999
      }
    }
  }

  NotifToasts { targetScreen: root.targetScreen }
}
