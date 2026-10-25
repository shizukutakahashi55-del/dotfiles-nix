# POWER — menú de energía y perfiles

- Qué es
  - Menú de apagado/reinicio/suspensión/hibernación/bloqueo/cierre de sesión con confirmación en dos pasos (`PowerMenu.qml`), lista de acciones (`PowerActions`) y perfiles `powerprofilesctl` (`PowerProfile`).
  - `shell.qml` expone el target IPC `powermenu` sobre el flag `powerOpen` (en `pillMode` va al dashboard, si no cierra otros popups).
- Archivos
  - `Modules/Power/PowerMenu.qml` → ventana (`open`/`targetScreen`): navegación `move/choose/back/activate`, `run(a)` vía `Quickshell.execDetached`, `pending` para confirmar.
  - `Modules/Power/PowerActions.qml` → singleton: `actions[]` (shutdown/reboot/suspend/hibernate/lock/logout), `byId(id)`, `run(action)`, `hyprshutdownCmd`/`logoutCmd`.
  - `Modules/Power/PowerProfile.qml` → singleton: perfil actual (`balanced`), `set(profile)`, `wanters` (pausar live wallpapers en `power-saver`).
  - `Modules/Power/PowerCard.qml` → tarjeta grande de acción (`icon/label/hint/danger/selected`).
  - `Modules/Power/PowerChip.qml` → chip pequeño (`icon/text/tone/battery`).
  - `Modules/Power/qmldir` → declara `singleton PowerActions`, `singleton PowerProfile`.
- IPC (Core/Ipc/PowerMenuIpc.qml, target `powermenu`):
  | target | función | efecto |
  |---|---|---|
  | `powermenu` | `toggle` | abre/cierra (respeta `pillMode` y backend rofi) |
  | `powermenu` | `open` | abre |
  | `powermenu` | `close` | cierra (`powerOpen = false`) |

  ```bash
  quickshell ipc -p .../shell.qml call -- powermenu toggle
  quickshell ipc -p .../shell.qml call -- powermenu open
  quickshell ipc -p .../shell.qml call -- powermenu close
  ```
- Estado y datos
  - Singletons: `PowerActions`, `PowerProfile` (`pragma Singleton`). Sin persistencia propia: la selección (`sel`) y `pending` son memoria del menú.
  - Comandos reales en `PowerActions.qml:27-46`: `systemctl poweroff` / `reboot` / `suspend` / `hibernate` (vía `hyprshutdown -t … --post-cmd` si `WM.has("hyprshutdown")`), `lock` llama a `quickshell ipc … call lock lock`, `logout` a `WM.logoutCommand()`.
- Dependencias
  - `COMMON` (`Theme`, `OozeIcons`, `WM`); `PowerMenu` lee `PowerActions.actions`; `Services/Walls` consulta `PowerProfile` para pausar vídeo en `power-saver`; `PowerChip` usa `Services/Battery/BatteryBackend.qml` (`percentage`/`charging`/`fullyCharged`/`isLow`).
- Notas
  - El menú tiene confirmación intermedia (`pending` de 2 filas sí/no) solo para acciones marcadas; `closesApps` distingue las destructivas.
  - `lock`/`logout` no ejecutan binarios directos sino IPC/comando del WM, así respetan el backend configurado (rofi o quickshell).
