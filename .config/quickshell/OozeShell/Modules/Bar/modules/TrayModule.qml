// TrayModule — bandeja del sistema; el menú de cada ícono lo abre el host de la isla.

import QtQuick

import "../../../COMMON"
import "../../Tray"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: tray.count > 0

  property int trayIconSize: 16

  Tray {
    id: tray

    iconSize: mod.trayIconSize
    renderScale: Theme.barScale
    activeItem: mod.host.trayMenuOpen ? mod.host.trayMenuEntry : null
    onTipEnter: item => mod.host.tipEnter(item)
    onTipLeave: item => mod.host.tipLeave(item)
    onMenuRequested: (iconItem, entry) => mod.host.openTrayMenu(iconItem, entry)
  }
}
