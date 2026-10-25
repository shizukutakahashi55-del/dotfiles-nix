# ALERTS — sonido y toast de las alertas de Agenda y Pomodoro

- Qué es: dos piezas compartidas por las alarmas del ToDo y los avisos del Pomodoro: el sonido (`AlertSound`) y un toast propio (`AlarmToast`) que no depende de «No Molestar».
- Archivos
  - `Services/Notify/AlertSound.qml` → singleton. `library` (sonidos del sistema + propios), `refresh()`, `play(path, volume, defaults)`, `importFile(path)`, `importStatus`, señal `imported(path)`.
  - `Services/Notify/AlarmToast.qml` → ventana overlay con cola de hasta 3 tarjetas. Clic la cierra; con `persistent` no expira, si no se oculta a los 10 s.
  - `Settings/SoundPicker.qml` → control de Ajustes: barra de volumen + botón de prueba, lista de sonidos y campo para agregar uno.
- Funcionamiento
  - Biblioteca: `*/stereo/*.oga` de `XDG_DATA_DIRS`, `/usr/share` y similares, más `~/.config/oozeshell/sounds/`. Los propios se listan primero.
  - Reproducción: `pw-play --volume` → `paplay --volume` → `canberra-gtk-play`. Si la ruta guardada no existe, usa el sonido freedesktop por defecto de cada servicio.
  - Agregar: acepta `.ogg .oga .wav .flac .mp3` (admite `~`, `$HOME` y `file://`); copia el archivo a la carpeta de sonidos y lo selecciona.
  - Toast: `NotificationsBackend.pushAlarm` guarda la alarma en el historial sin popup y emite `alarmRaised`; `AlarmToast` la muestra siempre, también con DND o con el centro abierto.
- Datos
  - Agenda: `alarmSoundFile`, `alarmVolume` en `~/.config/oozeshell/todos.toml`.
  - Pomodoro: opciones `soundFile`, `volume` (0-100, por defecto 100) del widget y del dashboard (`pomodoro.toml`).
- Integraciones: `TodoBackend.fireAlarm`, `PomodoroService.alert`, `shell.qml` (monta `AlarmToast`), páginas Agenda y Focus de Ajustes.
