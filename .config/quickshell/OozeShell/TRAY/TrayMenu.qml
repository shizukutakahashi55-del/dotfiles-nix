// TrayMenu — menú de un ícono de la bandeja, como popup de la barra.
// El host (RightModules) le pasa qué ítem mostrar (trayItem) y dónde (anchorX / anchorY, en coordenadas de PANTALLA, centro del ícono): sale debajo del ícono si la barra es horizontal, y a su costado si es vertical.

import QtQuick
import "../COMMON"

Item {
  id: root

  property bool open: false
  property var trayItem: null


  property real anchorX: 0
  property real anchorY: 0
  property string targetScreen: ""
  signal closeRequested()

  property int menuWidth: 250

  property int maxListHeight: 420
  property int edgeMargin: 10

  FusedWindow {
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-tray"
    onCloseRequested: root.closeRequested()

    FusedPanel {
      id: panel

      open: root.open && root.trayItem !== null
      panelWidth: root.menuWidth
      contentHeight: list.implicitHeight


      align: "center"

      island: Theme.pillMode ? "right" : ""


      alignMargin: root.edgeMargin + Theme.barEdge + Theme.frameSideArm
      alignCenter: Theme.barVertical ? root.anchorY : root.anchorX


      Behavior on x {
        enabled: panel.shown && !Theme.barVertical && !panel.hull
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }
      Behavior on y {
        enabled: panel.shown && Theme.barVertical
        NumberAnimation { duration: Theme.animDuration(160); easing.type: Easing.OutCubic }
      }

      TrayMenuList {
        id: list
        width: parent.width
        height: implicitHeight
        trayItem: root.trayItem
        maxListHeight: root.maxListHeight
        onCloseRequested: root.closeRequested()
      }
    }
  }
}
