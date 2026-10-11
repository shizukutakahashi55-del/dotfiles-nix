// NotifItem — envuelve UNA notificación.
// Quickshell entrega objetos Notification "crudos" (sin hora, sin estado de popup). Este wrapper agrega lo que necesita una UI tipo swaync: cuándo llegó ("5m"), si toca mostrarla como popup, cuánto dura ese

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../LANG"

QtObject {
  id: item


  signal removeRequested()

  property var notification: null

  property bool popup: false
  property bool closed: false


  property bool leaving: false
  property bool hovered: false
  property bool expanded: false

  property bool ephemeral: false

  property date time: new Date()
  property int ageMins: 0

  property string notifId: ""
  property string summary: ""
  property string body: ""
  property string appIcon: ""
  property string appName: ""
  property string image: ""
  property int urgency: NotificationUrgency.Normal
  property real expireTimeout: 0
  property bool resident: false

  property var actions: []


  property string groupKey: ""
  property bool groupFirst: false
  property int groupCount: 1

  readonly property var visibleActions: actions.filter(a => a.identifier !== "default")
  readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null

  readonly property string timeStr: {
    if (ageMins < 1) return Translations.t("notifNow")
    const h = Math.floor(ageMins / 60)
    const d = Math.floor(h / 24)
    if (d > 0) return d + "d"
    if (h > 0) return h + "h"
    return ageMins + "m"
  }


  readonly property string iconSource: {
    const n = appIcon
    if (!n) return ""
    if (n.startsWith("/")) return "file://" + n
    if (n.startsWith("file:") || n.startsWith("image://")) return n
    return Quickshell.iconPath(n)
  }


  readonly property int popupMs: {
    if (urgency === NotificationUrgency.Critical) return 0
    let t = expireTimeout
    if (t > 0) {
      if (t < 100) t = t * 1000
      return Math.max(2500, Math.min(20000, t))
    }
    return urgency === NotificationUrgency.Low ? 5000 : 8000
  }

  readonly property Timer popupTimer: Timer {
    interval: item.popupMs


    running: item.popup && !item.hovered && !item.expanded && item.popupMs > 0
    repeat: false
    onTriggered: item.expirePopup()
  }

  readonly property Timer ageTimer: Timer {
    interval: 30000
    running: !item.closed
    repeat: true
    onTriggered: item.updateAge()
  }


  readonly property Timer leaveTimer: Timer {
    interval: 210
    repeat: false
    onTriggered: item.removeRequested()
  }


  readonly property Timer destroyTimer: Timer {
    interval: 2000
    running: item.closed
    repeat: false
    onTriggered: item.destroy()
  }

  readonly property Connections conn: Connections {
    target: item.notification


    function onClosed() { item.popup = false }
    function onSummaryChanged() { item.summary = item.notification.summary }
    function onBodyChanged() { item.body = item.notification.body }
    function onAppIconChanged() { item.appIcon = item.notification.appIcon }
    function onAppNameChanged() { item.appName = item.notification.appName }
    function onImageChanged() { item.image = item.notification.image }
    function onUrgencyChanged() { item.urgency = item.notification.urgency }
    function onActionsChanged() { item.actions = item.mapActions(item.notification.actions) }
  }

  function mapActions(list) {
    const out = []
    for (const a of list) {
      out.push({ identifier: a.identifier, text: a.text, invoke: () => a.invoke() })
    }
    return out
  }

  function updateAge() {
    ageMins = Math.floor((Date.now() - time.getTime()) / 60000)
  }

  function expirePopup() {
    popup = false
    if (ephemeral) close(false)
  }

  function invokeAction(a) {
    a.invoke()
    if (!resident) close()
  }


  function close(dismiss = true) {
    if (closed) return
    closed = true
    popup = false
    const n = notification
    if (dismiss && n) {
      try { n.dismiss() } catch (e) {  }
    }


    leaving = true
    leaveTimer.start()
  }

  Component.onCompleted: {
    const n = notification
    if (!n) return


    if (!notifId) notifId = String(n.id)
    summary = n.summary
    body = n.body
    appIcon = n.appIcon
    appName = n.appName
    image = n.image
    expireTimeout = n.expireTimeout
    urgency = n.urgency
    resident = n.resident
    actions = mapActions(n.actions)
  }
}
