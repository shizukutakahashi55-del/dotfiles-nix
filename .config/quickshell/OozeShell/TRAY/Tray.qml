// Tray — bandeja del sistema (reemplaza el módulo "tray" de Waybar).
//
// Este archivo NO dibuja ni el tooltip ni el menú: solo avisa por señales
// (tipEnter / tipLeave / menuRequested) y el host (RightModules) los
// muestra con la misma lógica que el resto de los popups. Antes el menú
// salía por `display()`, que abre un menú nativo del sistema (otra
// tipografía, otro color, sin animación) — por eso desentonaba.
//
// Aislado en su propio archivo porque esta API es la más sensible a la
// versión de Quickshell instalada.
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

import "../COMMON"

BarFlow {
  id: tray

  property int iconSize: 18
  // El ítem cuyo menú está abierto (se dibuja "activo")
  property var activeItem: null

  readonly property int count: rep.count

  signal tipEnter(var item)
  signal tipLeave(var item)
  // iconItem = el botón (para posicionar el menú debajo), entry = SystemTrayItem
  signal menuRequested(var iconItem, var entry)

  gap: 0

  Repeater {
    id: rep
    model: SystemTray.items

    delegate: Rectangle {
      id: trayItem
      required property SystemTrayItem modelData

      readonly property bool active: tray.activeItem === trayItem.modelData

      readonly property string tip: {
        const t = modelData.tooltipTitle || modelData.title || modelData.id || ""
        const d = modelData.tooltipDescription || ""
        return d !== "" ? t + "\n" + d : t
      }

      Layout.preferredWidth: tray.iconSize + 8
      Layout.preferredHeight: 26
      radius: 8

      color: (itemArea.containsMouse || trayItem.active) ? Theme.surface : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

      scale: itemArea.pressed ? 0.85 : (itemArea.containsMouse ? 1.08 : 1.0)
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(140); easing.type: Easing.OutBack } }

      IconImage {
        anchors.centerIn: parent
        width: tray.iconSize
        height: tray.iconSize
        asynchronous: true
        source: trayItem.modelData.icon
      }

      MouseArea {
        id: itemArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: tray.tipEnter(trayItem)
        onExited: tray.tipLeave(trayItem)

        onClicked: mouse => {
          const it = trayItem.modelData
          if (mouse.button === Qt.RightButton) {
            if (it.hasMenu) tray.menuRequested(trayItem, it)
            else it.secondaryActivate()
          } else if (mouse.button === Qt.MiddleButton) {
            it.secondaryActivate()
          } else {
            if (it.onlyMenu && it.hasMenu) tray.menuRequested(trayItem, it)
            else it.activate()
          }
        }
      }
    }
  }
}
