# NOTIFY — servidor de notificaciones, centro y toasts

- Qué es
  - Servidor `NotificationServer` persistente + centro de notificaciones (`Notify.qml`) + toasts (`NotifToasts.qml`). El estado compartido vive en el singleton `NotificationsBackend`.
  - `shell.qml` expone el target IPC `notify`; el centro de notificaciones es `Services/Notify/Notify.qml`.
- Archivos
  - `Services/Notify/NotificationsBackend.qml` → singleton: `NotificationServer` (`keepOnReload`), lista `list/ordered/displayOrdered`, `dnd`, `pushLocal/pushAlarm/adopt/clearAll/clearGroup/toggleDnd/shouldPopup`.
  - `Services/Notify/NotifItem.qml` → envoltorio por notificación (popup/expire/agrupación `groupKey`, acciones, timers).
  - `Services/Notify/Notify.qml` → centro (`open`/`targetScreen`, namespace `oozeshell-notifications`).
  - `Services/Notify/NotifList.qml` → lista agrupada del centro.
  - `Services/Notify/NotifCard.qml` → tarjeta individual (requiere `notif`).
  - `Services/Notify/NotifToasts.qml` → toasts flotantes (máx. 4, namespace `oozeshell-toasts`).
  - `Services/Notify/AlarmToast.qml` → toast de alarmas (Agenda/Pomodoro): cola de hasta 3 tarjetas, overlay inferior, namespace `oozeshell-alarm-toast`. Se monta en `shell.qml` y escucha `NotificationsBackend.alarmRaised`.
  - `Services/Notify/AlertSound.qml` → singleton de sonido de alertas (ver ALERTS.md).
  - `Services/Notify/qmldir` → declara `singleton NotificationsBackend`.
- IPC (Core/Ipc/NotifyIpc.qml, target `notify`):
  | función | efecto |
  |---|---|
  | `toggle` | abre/cierra el centro |
  | `show <texto>` | notificación local (`pushLocal`) |
  | `toggleDnd` / `enableDnd` / `disableDnd` / `isDnd` | conmutar/forzar/consultar No Molestar |
  | `clear` | cierra todo (`clearAll`) |
  | `state` | JSON `{count,dnd}` |

  ```bash
  quickshell ipc -p .../shell.qml call -- notify toggle
  quickshell ipc -p .../shell.qml call -- notify show 'Layout: master'
  quickshell ipc -p .../shell.qml call -- notify toggleDnd
  quickshell ipc -p .../shell.qml call -- notify state
  ```
- Estado y datos
  - Singleton: `NotificationsBackend` (`pragma Singleton`). `dnd: bool`, `dndAllowCritical: bool`, `centerOpen`, `otherPopupOpen`, `list/ordered/displayPopups`.
  - DND se guarda en el `StateStore` (`StateStore.get("dnd")` / `setCommon("dnd", …)`, `NotificationsBackend.qml:45-58`); al activar DND se ocultan los popups. Sin JSON en `~/.config/oozeshell` ni caché propia.
  - `regroup()` agrupa por `appName`; `syncDisplay`/`syncDisplayPopups` vía `Qt.callLater` para no re-evaluar en cada cambio.
- Dependencias
  - `Quickshell.Services.Notifications` (`NotificationServer`, `NotificationUrgency`) y `Core` (`StateStore`, persistencia del DND); `NotifItem`/`NotifCard`/`NotifToasts` leen `Theme` (`COMMON`) para tamaños/colores.
- Notas
  - `pushAlarm(summary, body, persistent)` es la vía de las alarmas de AGENDA y POMODORO: guarda la notificación en el historial sin popup propio y emite `alarmRaised`; el aviso visible es `AlarmToast`, que ignora No Molestar. `persistent=true` mantiene el toast hasta cerrarlo; si no, se oculta a los 10 s.
  - Con `centerOpen` u `otherPopupOpen` activos, `shouldPopup()` devuelve `false`: no salen toasts mientras otro popup está abierto.
  - Superficies por modo: en barra el panel de avisos es la sección `notifs` del Dashboard (`Modules/Dashboard/DashboardNotifications.qml`, que reutiliza `NotifList`); en píldora la lista la pone `Modules/Pill/PillNotifications.qml` y el panel del Dashboard no existe. `Services/Notify/Notify.qml` sigue montado porque hospeda `NotifToasts` y sincroniza `NotificationsBackend.centerOpen` con su `open` (su propio panel solo actúa sin `Theme.pillMode`).
