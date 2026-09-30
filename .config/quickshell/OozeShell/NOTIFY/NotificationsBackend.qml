// NotificationsBackend — instancia única y persistente del servidor de
// notificaciones + el estado que comparten campana, panel y toasts.
//
// IMPORTANTE: NotificationServer NO es un singleton en Quickshell, hay
// que crearlo una sola vez en algún lugar que viva todo el tiempo (por
// eso está acá).
//
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
  // 
  //
  //
  //
Singleton {

  id: root

  // ─── Estado público ────────────────────────────────────────────
  // No molestar: no aparecen toasts, pero SÍ se guardan en el panel
  property bool dnd: false
  // Si true, las críticas igual muestran toast aunque haya DND
  property bool dndAllowCritical: false
  // Lo setea Notify.qml. Con el panel abierto no hacen falta toasts.
  property bool centerOpen: false
  // Lo setea shell.qml: true si hay CUALQUIER OTRO popup de la barra
  // abierto (Menu, Red, Audio, Ajustes, etc). Todos esos paneles y los
  // toasts cuelgan del mismo costado de la barra y son ventanas de capa
  // Overlay independientes — sin esto, abrir el Menú mientras hay un
  // toast en pantalla lo dejaba dibujado ENCIMA del panel recién abierto
  // (dos superficies Overlay peleando por el mismo rincón, sin relación
  // de z-order garantizada entre sí).
  property bool otherPopupOpen: false

  // NotifItem[], la más nueva primero
  property var list: []
  // Lo mismo pero agrupado por app (grupos ordenados por su más nueva)
  property var ordered: []

  // La UI (ListViews de Notify.qml y NotifToasts.qml) lee ESTAS dos, no
  // `ordered`/`popups` directamente. Motivo: "Limpiar todo", cerrar un
  // grupo entero, o apagar DND con varios toasts activos, recorren la
  // lista y cierran/ocultan VARIOS ítems seguidos en el mismo tick —
  // cada uno dispara su propio recálculo completo de `ordered`/`popups`,
  // así que el ListView terminaba reconstruyendo su modelo varias veces
  // de golpe (eso se veía como notificaciones que se pisan o parpadean).
  // Qt.callLater junta todos esos recálculos de un mismo tick en uno
  // solo, en el próximo turno del loop — mismo truco que ya usamos para
  // el crash del buscador del Launcher.
  property var displayOrdered: []
  onOrderedChanged: Qt.callLater(root.syncDisplay)
  function syncDisplay() { root.displayOrdered = root.ordered }

  readonly property int count: list.length
  // Toasts activos (se recalcula cuando cambia la lista o algún .popup)
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

  // Secuencia propia de notifId, independiente del id que reparte el
  // servidor de notificaciones. Por qué hace falta una propia: el id de
  // Quickshell (notification.id) arranca de nuevo en 1 en cada recarga
  // de config, pero acá seguimos mostrando notificaciones viejas
  // (keepOnReload) que ya usaban esos mismos números — sin esto, una
  // notificación nueva podía terminar con el MISMO notifId que una vieja
  // todavía en pantalla. El ScriptModel de Notify.qml / NotifToasts.qml
  // identifica cada fila por su notifId (objectProp): con dos ítems
  // distintos compartiendo id, lo trata como una única fila, así que uno
  // tapa al otro y el resto de la lista queda mal reacomodada — eso es
  // lo que se veía como notificaciones "perdidas" (30 recibidas, 3
  // visibles) en ráfagas largas. root.notifSeq vive en este singleton,
  // que es único y persistente, así que nunca se reinicia mientras dure
  // la sesión.
  property int notifSeq: 0
  function nextNotifId() { return "n" + (++root.notifSeq) }

  // Aviso local (sin Notification real): lo usa `notify show <texto>`.
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

  // Aviso de alarma (recordatorios del ToDo, AGENDA/TodoBackend.qml).
  // A diferencia de pushLocal NO es efímero: queda en el panel hasta que se
  // cierre a mano. `persistent` = urgencia crítica → el toast tampoco se
  // esconde solo (y, con No molestar, solo se muestra si "permitir críticas"
  // está activo; igual queda guardado en el panel).
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

  // Agrupa por app manteniendo el orden por recencia
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

    // Capacidades que anunciamos (las apps deciden qué mandar según esto)
    keepOnReload: true
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyHyperlinksSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: notification => {
      // tracked = true la mantiene viva hasta que alguien la cierre
      notification.tracked = true
      root.adopt(notification, root.shouldPopup(notification.urgency))
    }
  }

  // Si se recargó la config con notificaciones vivas (keepOnReload),
  // las volvemos a envolver para que aparezcan en el panel.
  Component.onCompleted: {
    for (const n of server.trackedNotifications.values) root.adopt(n, false)
  }
}
