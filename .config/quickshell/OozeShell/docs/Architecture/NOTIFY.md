# NOTIFY — servidor de notificaciones, centro y toasts

- Qué es
  - Servidor `NotificationServer` persistente + centro de notificaciones (`Notify.qml`) + toasts (`NotifToasts.qml`). El estado compartido vive en el singleton `NotificationsBackend`.
  - `shell.qml` expone el target IPC `notify` y el popup `notifyOpen` (en `pillMode` va al dashboard, si no al `menuTab "notifs"`).
- Archivos
  - `NOTIFY/NotificationsBackend.qml` → singleton: `NotificationServer` (`keepOnReload`), lista `list/ordered/displayOrdered`, `dnd`, `pushLocal/pushAlarm/adopt/clearAll/clearGroup/toggleDnd/shouldPopup`.
  - `NOTIFY/NotifItem.qml` → envoltorio por notificación (popup/expire/agrupación `groupKey`, acciones, timers).
  - `NOTIFY/Notify.qml` → centro (`open`/`targetScreen`, namespace `oozeshell-notifications`).
  - `NOTIFY/NotifList.qml` → lista agrupada del centro.
  - `NOTIFY/NotifCard.qml` → tarjeta individual (requiere `notif`).
  - `NOTIFY/NotifToasts.qml` → toasts flotantes (máx. 4, namespace `oozeshell-toasts`).
  - `NOTIFY/qmldir` → declara `singleton NotificationsBackend`.
- IPC
  | target | función | efecto |
  |---|---|---|
  | `notify` | `toggle` | abre/cierra el centro |
  | `notify` | `show <texto>` | notificación local (`pushLocal`) |
  | `notify` | `toggleDnd` / `enableDnd` / `disableDnd` / `isDnd` | conmutar/forzar/consultar No Molestar |
  | `notify` | `clear` | cierra todo (`clearAll`) |
  | `notify` | `state` | JSON `{count,dnd}` |

  ```bash
  quickshell ipc -p .../shell.qml call -- notify toggle
  quickshell ipc -p .../shell.qml call -- notify show 'Layout: master'
  quickshell ipc -p .../shell.qml call -- notify toggleDnd
  quickshell ipc -p .../shell.qml call -- notify state
  ```
- Estado y datos
  - Singleton: `NotificationsBackend` (`pragma Singleton`). `dnd: bool`, `dndAllowCritical: bool`, `centerOpen`, `otherPopupOpen`, `list/ordered/displayPopups`.
  - DND persiste en `~/.cache/oozeshell-dnd` (`"1"`/`"0"`, `dndFile` en `NotificationsBackend.qml:43`); al activar DND se ocultan los popups. Sin JSON en `~/.config/oozeshell`.
  - `regroup()` agrupa por `appName`; `syncDisplay`/`syncDisplayPopups` vía `Qt.callLater` para no re-evaluar en cada cambio.
- Dependencias
  - `Quickshell.Services.Notifications` (`NotificationServer`, `NotificationUrgency`); `NotifItem`/`NotifCard`/`NotifToasts` leen `Theme` para tamaños/colores.
- Notas
  - `pushAlarm(summary, body, persistent)` es la vía de las alarmas de AGENDA: `persistent=true` crea urgencia crítica (sobrevive al DND solo si `dndAllowCritical`).
  - Con `centerOpen` u `otherPopupOpen` activos, `shouldPopup()` devuelve `false`: no salen toasts mientras otro popup está abierto.
