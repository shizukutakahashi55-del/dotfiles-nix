// NotificationsBackend — instancia única y persistente del servidor de notificaciones + el estado que comparten campana, panel y toasts.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications


Singleton {

  id: root

  // ─── Estado público ────────────────────────────────────────────

  property bool dnd: false

  property bool dndAllowCritical: false

  property bool centerOpen: false


  property bool otherPopupOpen: false


  property var list: []

  property var ordered: []


  property var displayOrdered: []
  onOrderedChanged: Qt.callLater(root.syncDisplay)
  function syncDisplay() { root.displayOrdered = root.ordered }

  readonly property int count: list.length

  readonly property var popups: list.filter(n => n.popup)
  property var displayPopups: []
  onPopupsChanged: Qt.callLater(root.syncDisplayPopups)
  function syncDisplayPopups() { root.displayPopups = root.popups }

  // ─── Persistencia del DND ──────────────────────────────────────
  readonly property string dndFile: Quickshell.env("HOME") + "/.cache/oozeshell-dnd"

  Process {
    id: loadDnd
    command: ["bash", "-c", "cat '" + root.dndFile + "' 2>/dev/null"]
    running: true
    stdout: SplitParser { onRead: line => root.dnd = (line.trim() === "1") }
  }

  Process {
    id: saveDnd
    property string value: "0"
    command: ["bash", "-c", "printf %s " + value + " > '" + root.dndFile + "'"]
    running: false
  }

  onDndChanged: {
    saveDnd.value = root.dnd ? "1" : "0"
    saveDnd.running = false
    saveDnd.running = true
    if (root.dnd) root.hideAllPopups()
  }

  onCenterOpenChanged: { if (root.centerOpen) root.hideAllPopups() }
  onOtherPopupOpenChanged: { if (root.otherPopupOpen) root.hideAllPopups() }

  // ─── API ───────────────────────────────────────────────────────
  function toggleDnd() { root.dnd = !root.dnd }

  function shouldPopup(urgency) {
    if (root.centerOpen || root.otherPopupOpen) return false
    if (root.dnd) return root.dndAllowCritical && urgency === NotificationUrgency.Critical
    return true
  }

  function hideAllPopups() {
    for (const n of root.list) n.popup = false
  }

  function clearAll() {
    for (const n of root.list.slice()) n.close()
  }

  function clearGroup(key) {
    for (const n of root.list.slice()) {
      if (n.groupKey === key) n.close()
    }
  }


  property int notifSeq: 0
  function nextNotifId() { return "n" + (++root.notifSeq) }


  function pushLocal(summary, body) {
    const item = itemComp.createObject(root, {
      notifId: root.nextNotifId(),
      summary: summary,
      body: body ?? "",
      appName: "OozeShell",
      urgency: NotificationUrgency.Low,
      ephemeral: true,
      popup: root.shouldPopup(NotificationUrgency.Low)
    })
    root.attach(item)
  }


  function pushAlarm(summary, body, persistent) {
    const urg = persistent ? NotificationUrgency.Critical : NotificationUrgency.Normal
    const item = itemComp.createObject(root, {
      notifId: root.nextNotifId(),
      summary: summary,
      body: body ?? "",
      appName: "OozeShell",
      urgency: urg,
      ephemeral: false,
      popup: root.shouldPopup(urg)
    })
    root.attach(item)
  }

  function adopt(notification, popup) {
    const item = itemComp.createObject(root, {
      notifId: root.nextNotifId(),
      notification: notification,
      popup: popup
    })
    root.attach(item)
  }

  function attach(item) {
    if (!item) return
    item.removeRequested.connect(() => root.remove(item))
    root.list = [item, ...root.list]
  }

  function remove(item) {
    root.list = root.list.filter(n => n !== item)
  }


  function regroup() {
    const order = []
    const map = {}
    for (const n of root.list) {
      const key = n.appName !== "" ? n.appName : "?"
      n.groupKey = key
      if (!map[key]) { map[key] = []; order.push(key) }
      map[key].push(n)
    }
    const flat = []
    for (const key of order) {
      const items = map[key]
      for (let i = 0; i < items.length; i++) {
        items[i].groupFirst = (i === 0)
        items[i].groupCount = items.length
        flat.push(items[i])
      }
    }
    root.ordered = flat
  }

  onListChanged: root.regroup()

  Component { id: itemComp; NotifItem {} }

  NotificationServer {
    id: server


    keepOnReload: true
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyHyperlinksSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: notification => {

      notification.tracked = true
      root.adopt(notification, root.shouldPopup(notification.urgency))
    }
  }


  Component.onCompleted: {
    for (const n of server.trackedNotifications.values) root.adopt(n, false)
  }
}
