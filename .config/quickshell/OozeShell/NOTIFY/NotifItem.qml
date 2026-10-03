// NotifItem — envuelve UNA notificación.
//
// Quickshell entrega objetos Notification "crudos" (sin hora, sin estado
// de popup). Este wrapper agrega lo que necesita una UI tipo swaync:
// cuándo llegó ("5m"), si toca mostrarla como popup, cuánto dura ese
// popup, y a qué grupo (app) pertenece.
//
// También sirve para avisos locales sin Notification real (ej. el
// "Layout: master" que manda `notify show`): notification = null.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../LANG"

QtObject {
  id: item

  // Lo emite close(); el backend lo saca de su lista.
  signal removeRequested()

  property var notification: null

  property bool popup: false
  property bool closed: false
  // Cierre en curso: la fila del panel se anima hacia afuera y RECIÉN después
  // (leaveTimer) se saca de la lista. `closed` ya es true desde el primer instante.
  property bool leaving: false
  property bool hovered: false
  property bool expanded: false
  // true = solo popup, no se guarda en el historial
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
  // [{ identifier, text, invoke }]
  property var actions: []

  // Los llena el backend al agrupar por app
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

  // Ícono de la app: nombre de tema, ruta absoluta o url
  readonly property string iconSource: {
    const n = appIcon
    if (!n) return ""
    if (n.startsWith("/")) return "file://" + n
    if (n.startsWith("file:") || n.startsWith("image://")) return n
    return Quickshell.iconPath(n)
  }

  // Cuánto dura el popup (ms). 0 = no se oculta solo (críticas).
  // Quickshell puede entregar expireTimeout en segundos o en ms según
  // la versión, así que valores < 100 se interpretan como segundos.
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
    // También se pausa si está expandida ("Ver detalles"): si el mouse se
    // corre un poco mientras se lee, el toast no debe desaparecer a mitad
    // de lectura.
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

  // Da tiempo a la animación de salida de la fila (Notify.qml, ~200 ms) antes de
  // pedirle al backend que la saque de la lista.
  readonly property Timer leaveTimer: Timer {
    interval: 210
    repeat: false
    onTriggered: item.removeRequested()
  }

  // Se destruye tarde a propósito: las animaciones de salida de la
  // lista todavía leen propiedades de este objeto.
  readonly property Timer destroyTimer: Timer {
    interval: 2000
    running: item.closed
    repeat: false
    onTriggered: item.destroy()
  }

  readonly property Connections conn: Connections {
    target: item.notification

    // OJO: esto NO debe ser item.close(false). onClosed se dispara cada
    // vez que la notificación "cruda" se cierra a nivel de protocolo —
    // cosa que pasa sola todo el tiempo (la app que la mandó le puso su
    // propio timeout y la cierra ella misma del lado del daemon), sin
    // relación con nuestro popupTimer. Si acá hiciéramos un cierre
    // completo, cada notificación desaparecería del historial del centro
    // apenas el emisor original la cerrara — igual que un toast. El
    // centro es historia persistente: solo debe vaciarse por una acción
    // explícita del usuario (botón "×", "Limpiar todo"/"Limpiar grupo"),
    // no porque la app de origen ya haya terminado de mostrarla.
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

  // dismiss=false cuando el cierre lo originó la propia app/servidor
  //
  // El try/catch de acá abajo es lo que arregla "Limpiar todo"/"Limpiar
  // grupo": esas dos funciones (NotificationsBackend.clearAll/clearGroup)
  // recorren varias notificaciones en un mismo `for` y llaman close() en
  // cada una. n.dismiss() habla con el server de notificaciones sobre el
  // objeto Notification "crudo" — que la app que la mandó puede haber
  // cerrado ya por su cuenta en CUALQUIER momento (con keepOnReload la
  // seguimos mostrando en el panel igual). Pedirle dismiss() a una
  // notificación que el server ya dio de baja tira una excepción de
  // Quickshell. Sin este try/catch, esa excepción cortaba el `for` del
  // caller en seco: todo lo que faltaba recorrer en la lista quedaba sin
  // cerrar (por eso "Limpiar todo" a veces borraba solo las primeras).
  function close(dismiss = true) {
    if (closed) return
    closed = true
    popup = false
    const n = notification
    if (dismiss && n) {
      try { n.dismiss() } catch (e) { /* ya estaba cerrada del lado del server; no pasa nada */ }
    }
    // Antes se pedía la baja acá mismo y la fila desaparecía de golpe. Ahora
    // primero se marca `leaving` (la fila se anima) y la baja llega 210 ms
    // después. Efímeras/toasts: no cambia nada visible (popup ya es false).
    leaving = true
    leaveTimer.start()
  }

  Component.onCompleted: {
    const n = notification
    if (!n) return
    // Solo si el backend no nos dio ya un notifId propio (ver
    // NotificationsBackend.adopt): el id que reparte el servidor de
    // notificaciones (n.id) se reinicia en 1 cada vez que Quickshell
    // recarga su config, mientras el panel puede seguir mostrando
    // notificaciones viejas con esos MISMOS números bajos (keepOnReload).
    // Si dos ítems distintos terminan con igual notifId, el ScriptModel
    // de Notify.qml / NotifToasts.qml (que identifica filas por notifId)
    // los trata como el mismo ítem: uno tapa al otro y el resto de la
    // lista queda mal calculada — eso es lo que se veía como
    // notificaciones que "se pierden" en ráfagas largas.
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
