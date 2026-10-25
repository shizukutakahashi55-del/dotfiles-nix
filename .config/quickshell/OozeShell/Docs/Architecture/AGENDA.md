# AGENDA — Calendario mensual + ToDo por fecha con alarmas

- Qué es: calendario mensual (sección del Dashboard) con panel lateral día/ToDo. Las tareas viven en el singleton `TodoBackend`, con hora opcional (`hh:mm`), alarmas por `NOTIFY` y sonido freedesktop.
- Archivos:
  - `Services/Agenda/AgendaView.qml` → UI: mes navegable, panel día ⇄ ToDo, crear/completar/borrar tareas, chip de hora clicable para quitarla.
  - `Services/Agenda/TodoBackend.qml` → `pragma Singleton`: CRUD, `pending`/`tasksFor`/`pendingFor`, `normTime`, alarmas (`checkAlarms` cada 15 s), persistencia.
- IPC (Core/Ipc/AgendaIpc.qml, target `agenda`):

  | función | efecto |
  |---|---|
  | `toggle` / `open` / `close` | abre/cierra la sección `calendar` del Dashboard |

  ```bash
  quickshell ipc -p .../shell.qml call -- agenda toggle
  quickshell ipc -p .../shell.qml call -- agenda open
  quickshell ipc -p .../shell.qml call -- agenda close
  ```
- Estado y datos: singleton `TodoBackend` (`Services/Agenda/TodoBackend.qml:3`). TOML en `~/.config/oozeshell/todos.toml` (`dir`/`file`, `TodoBackend.qml:26-27`): `items`, `nextId`, `showTodo`, `alarmsEnabled`, `alarmSound`, `alarmPersistent`, `alarmSoundFile`, `alarmVolume`. Sin caché en `~/.cache`.
- Dependencias: `COMMON` (Theme), `Services/Lang` (Translations), `Services/Notify` (NotificationsBackend.pushAlarm, AlertSound, AlarmToast). Ajustes: `Settings/TodoAlarmSettings.qml` usa `Settings/SoundPicker.qml` (volumen, lista de sonidos, agregar). Vista en dashboard reutiliza `AgendaView` con `dash: true`.
- Notas: `normTime` acepta `H`, `HHMM` y `H:MM`; tareas con hora pasada se marcan `notified` al crearlas para no disparar alarma tardía. Solo dispara notificación si venció hace ≤ 6 h (`checkAlarms`). El calendario y las tareas se muestran en el Dashboard (`Modules/Dashboard/DashboardCalendar.qml` y `Modules/Dashboard/DashboardTodo.qml`, esta última dentro de la página Enfoque `Modules/Dashboard/DashboardFocus.qml`); `Services/Agenda/AgendaPopup.qml` ya no existe.

- Modo día (lista cerrada): bajo la fecha se listan las tareas del día seleccionado (`dayView.dayTasks`); pulsar una la marca como hecha. El botón inferior sigue abriendo la lista para añadir.
