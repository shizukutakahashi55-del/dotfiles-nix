// BarSectionRow — contenido de una isla de la barra, armado desde la distribución elegida en Ajustes → Barra → Módulos (Theme.barModulesOf).

import QtQuick
import QtQuick.Layouts

import "../../../COMMON"
import "../modules"

BarFlow {
  id: row

  property string side: "left"
  property var host: null

  readonly property var ids: Theme.barModulesOf(row.side)

  property int visibleCount: 0
  readonly property bool occupied: row.visibleCount > 0

  property var sepFlags: []
  property real othersHeight: 0

  gap: 2

  readonly property var glue: ({})

  function refresh() {
    let seen = false
    let prevId = ""
    let count = 0
    let others = 0
    const flags = []
    for (let i = 0; i < rep.count; i++) {
      const s = rep.itemAt(i)
      const vis = !!s && s.slotVisible
      const glued = vis && seen && row.glue[s.moduleId] === prevId
      flags.push(vis && seen && !glued)
      if (!vis) continue
      seen = true
      prevId = s.moduleId
      count++
      if (s.moduleId !== "taskbar") others += s.implicitHeight + 10
    }
    row.sepFlags = flags
    row.visibleCount = count
    row.othersHeight = others
  }

  onIdsChanged: Qt.callLater(row.refresh)

  Component.onCompleted: { Qt.callLater(row.refresh); settle.restart() }
  Timer { id: settle; interval: 350; repeat: false; onTriggered: row.refresh() }

  Component { id: cPower; PowerModule { host: row.host } }
  Component { id: cLang; LangModule { host: row.host } }
  Component { id: cMpris; MprisModule { host: row.host } }
  Component { id: cNotifications; NotificationsModule { host: row.host } }
  Component { id: cWorkspaces; WorkspacesModule { host: row.host } }
  Component { id: cClock; ClockModule { host: row.host } }
  Component { id: cAudio; AudioModule { host: row.host } }
  Component { id: cBattery; BatteryModule { host: row.host } }
  Component { id: cPrivacy; PrivacyModule { host: row.host } }
  Component { id: cTaskbar; TaskbarModule { host: row.host } }
  Component { id: cTray; TrayModule { host: row.host } }
  Component { id: cMenu; MenuModule { host: row.host } }

  function componentFor(id) {
    switch (id) {
      case "power": return cPower
      case "lang": return cLang
      case "mpris": return cMpris
      case "notifications": return cNotifications
      case "workspaces": return cWorkspaces
      case "clock": return cClock
      case "audio": return cAudio
      case "battery": return cBattery
      case "privacy": return cPrivacy
      case "taskbar": return cTaskbar
      case "tray": return cTray
      case "menu": return cMenu
    }
    return null
  }

  Repeater {
    id: rep
    model: row.ids

    onItemAdded: Qt.callLater(row.refresh)
    onItemRemoved: Qt.callLater(row.refresh)

    delegate: BarFlow {
      id: slot

      readonly property string moduleId: modelData
      readonly property bool slotVisible: loader.item !== null && loader.item.shown === true

      gap: 2
      visible: slot.slotVisible

      onSlotVisibleChanged: Qt.callLater(row.refresh)
      onImplicitHeightChanged: Qt.callLater(row.refresh)

      Rectangle {
        visible: row.sepFlags[index] === true
        Layout.preferredWidth: Theme.barVertical ? 18 : 1
        Layout.preferredHeight: Theme.barVertical ? 1 : 15
        Layout.alignment: Qt.AlignCenter
        radius: 1
        color: Theme.primary
        opacity: 0.25
      }

      Loader {
        id: loader
        sourceComponent: row.componentFor(slot.moduleId)
      }
    }
  }
}
