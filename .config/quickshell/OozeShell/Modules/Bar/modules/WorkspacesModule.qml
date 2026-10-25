// WorkspacesModule — puntos de los escritorios de esta pantalla.

import QtQuick

import "../../../COMMON"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: true

  gap: 2

  WorkspaceDots {
    workspaces: WM.dotsWorkspacesFor(mod.host.screenName ?? "")
    vertical: Theme.barVertical
  }
}
