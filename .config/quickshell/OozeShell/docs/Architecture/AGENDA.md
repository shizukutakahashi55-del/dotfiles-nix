# AGENDA — Calendario mensual + ToDo por fecha con alarmas

- Qué es: popup de calendario con vista mensual y panel lateral día/ToDo. Las tareas viven en el singleton `TodoBackend`, con hora opcional (`hh:mm`), alarmas por `NOTIFY` y sonido freedesktop.
- Archivos:
  - `AGENDA/AgendaPopup.qml` → contenedor `FusedWindow`/`FusedPanel` que se abre con clic derecho en el reloj (barra clásica e islas).
  - `AGENDA/AgendaView.qml` → UI: mes navegable, panel día ⇄ ToDo, crear/completar/borrar tareas, chip de hora clicable para quitarla.
  - `AGENDA/TodoBackend.qml` → `pragma Singleton`: CRUD, `pending`/`tasksFor`/`pendingFor`, `normTime`, alarmas (`checkAlarms` cada 15 s), persistencia.
- IPC:

  | target | función | efecto |
  |---|---|---|
  | `agenda` | `toggle` / `open` / `close` | abre/cierra popup (o dashboard `calendar` en `pillMode`) |

  ```bash
  quickshell ipc -p .../shell.qml call -- agenda toggle
  quickshell ipc -p .../shell.qml call -- agenda open
  quickshell ipc -p .../shell.qml call -- agenda close
  ```
- Estado y datos: singleton `TodoBackend` (`AGENDA/TodoBackend.qml:3`). JSON en `~/.config/oozeshell/todos.json` (`dir`/`file`, `TodoBackend.qml:26-27`): `items`, `nextId`, `showTodo`, `alarmsEnabled`, `alarmSound`, `alarmPersistent`. Sin caché en `~/.cache`.
- Dependencias: `import ../COMMON` (Theme, FusedWindow, FusedPanel), `../LANG` (Translations), `../NOTIFY` (NotificationsBackend.pushAlarm). Vista en dashboard reutiliza `AgendaView` con `dash: true`.
- Notas: `normTime` acepta `H`, `HHMM` y `H:MM`; tareas con hora pasada se marcan `notified` al crearlas para no disparar alarma tardía. Solo dispara notificación si venció hace ≤ 6 h (`checkAlarms`).
