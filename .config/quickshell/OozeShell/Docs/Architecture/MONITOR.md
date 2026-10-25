# MONITOR — selector de monitor y editor visual (Hyprland)

- Qué es: dos piezas. `MonitorSelect.qml` es el popup para elegir en qué monitor se abren los paneles; `MonitorEditor.qml` es un editor visual de disposición/resolución/escala reservado a Hyprland que genera `monitors.lua`.
- Archivos:
  - `Services/Monitor/MonitorSelect.qml` → popup (`oozeshell-monitor`) con fila `auto` + lista de monitores; emite `monitorChosen(name)`
  - `Services/Monitor/MonitorEditor.qml` → editor (`oozeshell-monitor-editor`); lee `hyprctl monitors -j`, previsualiza el lienzo y escribe el `monitors.lua`
- IPC (Core/Ipc/MonitorIpc.qml, target `monitor`):

  | Función | Efecto |
  |---|---|
  | `set <nombre>` | fija `root.targetMonitor` (`auto` = seguimiento de foco) |
  | `get` | devuelve el monitor objetivo configurado |
  | `togglePicker` | alterna el popup selector |
  | `list` | lista monitores (`Quickshell.screens`, separados por `, `) |
  | `current` | monitor con foco actual (`resolveMonitor()`) |

  ```sh
  quickshell ipc -p .../shell.qml call -- monitor set DP-3
  quickshell ipc -p .../shell.qml call -- monitor get
  quickshell ipc -p .../shell.qml call -- monitor togglePicker
  quickshell ipc -p .../shell.qml call -- monitor list
  ```
- Estado y datos: sin singleton. `setMonitor`/`targetMonitor`/`resolveMonitor` viven en `shell.qml` (~línea 151). El editor escribe `~/.config/hypr/modules/hardware/settings/monitors.lua` (`Services/Monitor/MonitorEditor.qml:391-392`) y aplica con `hyprctl`; la capacidad está tras `WM.has("monitorEditor")` (solo Hyprland según `capTable` en `COMMON/WM.qml:75-90`).
- Dependencias: `COMMON`, `Services/Lang`, `Quickshell.Io` (`Process` + `hyprctl`).
- Notas: `get` vs `current` difieren: `get` es la preferencia guardada (`auto` incluido), `current` es el monitor enfocado ahora mismo.
