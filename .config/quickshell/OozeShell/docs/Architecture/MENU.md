# MENU — menú rápido, overview de ventanas y píldora contenedora

- Qué es: tres piezas relacionadas. `MENU` es el panel de ajustes rápidos; `OVERVIEW` es el conmutador de workspaces/ventanas; `PILL` es la barra/píldora que los hospeda junto al `DASHBOARD` (en modo píldora varios popups se convierten en secciones del dashboard).

## Menu (`OozeShell/MENU`)

- Archivos:
  - `MENU/Menu.qml` → panel (`oozeshell-menu`) con toggles: red (`NetworkBackend`), bluetooth, brillo, audio, notificaciones, energía
  - `MENU/SystemStats.qml` → CPU/RAM/GPU/disco vía `Process`
  - `MENU/MetricCard.qml` → tarjeta de métrica reutilizable
  - `MENU/Sparkline.qml` → mini-gráfico (`QtQuick.Shapes`, sin dependencias)
  - `MENU/AudioControl.qml` → controles de volumen vía `Process`
- IPC (`shell.qml`, target `menu`):

  | Función | Efecto |
  |---|---|
  | `toggle` | en modo píldora abre sección `quickaccess` del dashboard; si no, popup propio |

  ```sh
  quickshell ipc -p .../shell.qml call -- menu toggle
  ```
- Estado y datos: sin singleton propio; `NetworkBackend.menuWatch = menuRoot.open` activa el monitoreo de red solo mientras el menú está abierto (`Menu.qml:74`).
- Dependencias: `../COMMON`, `../LANG`, `../NETWORK`, `../BLUETOOTH`, `../POWER`, `../BRIGHTNESS`, `../NOTIFY`.

## Overview (`OozeShell/OVERVIEW`)

- Archivos:
  - `OVERVIEW/Overview.qml` → popup (`oozeshell-overview`) con workspaces, miniaturas de ventanas y búsqueda; toda la info de ventanas sale de `WM`
- IPC (`shell.qml`, target `overview`):

  | Función | Efecto |
  |---|---|
  | `toggle` / `open` / `close` | si `WM.hasNativeOverview`, delega al overview nativo del compositor; si no, popup propio o sección `overview` del dashboard en modo píldora |

  ```sh
  quickshell ipc -p .../shell.qml call -- overview toggle
  quickshell ipc -p .../shell.qml call -- overview open
  quickshell ipc -p .../shell.qml call -- overview close
  ```
- Estado y datos: sin estado propio; `clients`/`monitors`/`workspacesFor` vienen de `WM` (`COMMON/WM.qml`); retiene clientes con `WM.retainClients("overview")` mientras está abierto.
- Dependencias: `../COMMON` (WM, AppState, Theme), `../LANG`, `Quickshell.Wayland`.

## Pill (`OozeShell/PILL`)

- Archivos:
  - `PILL/Pill.qml` → barra/píldora por monitor (`oozeshell-pill`), hospeda `Dashboard`, `Menu`, taskbar y reloj; gestiona auto-hide y foco de teclado
  - `PILL/PillClock.qml` → reloj
  - `PILL/PillMedia.qml` → controles MPRIS compactos (lee `MprisBackend`)
  - `PILL/PillNotifications.qml` → indicador de notificaciones
  - `PILL/PillTaskbar.qml` → taskbar (reexporta `TASKBAR`)
  - `PILL/PillTray.qml` → bandeja del sistema
  - `PILL/PillWorkspaces.qml` / `PillWorkspacesSide.qml` → indicadores de workspaces (el lateral usa namespace `oozeshell-pill-workspaces`)
- IPC: sin target propio; se interactúa vía `menu`, `overview`, `mpris` y los IPC de `Theme.pillMode` (ver `BAR.md` si existe).
- Estado y datos: `AppState` (`COMMON/AppState.qml`): `dashboardOpen`, `dashboardScreen`, `dashboardSection`, `pillAutoHide`, `pillHiddenNow`, `pillTraySync`, `trayVisible`.
- Dependencias: `../COMMON` (AppState, WM, Theme), `../LANG`, `../TASKBAR`, `../DASHBOARD`, `../NOTIFY`, `../MPRIS` (solo `PillMedia.qml`).
- Notas: clic en la píldora abre el dashboard (`AppState.toggleDashboard`); clic derecho abre la sección `calendar`. Con `pillAutoHide` la píldora se oculta y deja una zona de disparo (`triggerH`); el `reserveZone` compensa `AppState.gapsOut`.
