// TaskbarModule — ventanas abiertas de esta pantalla. En barra vertical limita cuántos íconos caben según el espacio libre de la isla.

import QtQuick

import "../../../COMMON"
import "../../Taskbar"

BarFlow {
  id: mod

  property var host: null
  readonly property bool shown: taskbar.count > 0

  property int taskbarIconSize: 16
  property bool taskbarAllOutputs: false
  property int taskbarMaxItems: 8

  readonly property int taskbarLimit: {
    if (!Theme.barVertical) return mod.taskbarMaxItems
    const avail = mod.host.verticalRoom
    const cells = Math.floor((avail / Theme.barScale - mod.host.othersHeight - 18) / 32)
    return Math.max(1, Math.min(mod.taskbarMaxItems, cells))
  }

  Binding {
    target: mod.host
    property: "taskbarWindows"
    value: taskbar.windows
  }

  Taskbar {
    id: taskbar

    targetScreen: mod.host.targetScreen
    iconSize: mod.taskbarIconSize
    allOutputs: mod.taskbarAllOutputs
    maxItems: mod.taskbarLimit

    compact: Theme.taskbarCompact
    onToggleCompact: Theme.setTaskbarCompact(!Theme.taskbarCompact)
    onTipEnter: item => mod.host.tipEnter(item)
    onTipLeave: item => mod.host.tipLeave(item)
    onMenuRequested: item => mod.host.openTaskbarMenu(item)
  }
}
