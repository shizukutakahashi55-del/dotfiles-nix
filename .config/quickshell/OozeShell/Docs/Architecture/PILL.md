# PILL — barra minimalista del modo píldora

- Qué es: la superficie que sustituye a la barra cuando `Theme.pillMode` está activo. Una `Pill` por
  monitor (`Variants` sobre `Quickshell.screens`, namespace `oozeshell-pill`) que hospeda el
  `Dashboard`, el reloj, los controles MPRIS, el indicador de notificaciones, la taskbar, la bandeja del
  sistema y los indicadores de workspaces. Gestiona auto-hide, zona de disparo y foco de teclado.
- Archivos:
  - `Modules/Pill/Pill.qml` → barra/píldora por monitor; hospeda `Modules/Dashboard/Dashboard.qml`,
    taskbar, reloj y bandeja; administra auto-hide y foco de teclado; clic abre el dashboard
    (`AppState.toggleDashboard`) y clic derecho abre la sección `calendar`
  - `Modules/Pill/PillClock.qml` → reloj
  - `Modules/Pill/PillMedia.qml` → controles MPRIS compactos (lee `Services/Mpris/MprisBackend.qml`)
  - `Modules/Pill/PillNotifications.qml` → indicador y lista de notificaciones de la píldora
  - `Modules/Pill/PillTaskbar.qml` → taskbar (reexporta `Modules/Taskbar/TaskbarList.qml`)
  - `Modules/Pill/PillTray.qml` → bandeja del sistema (`Modules/Tray/TrayMenuList.qml`)
  - `Modules/Pill/PillWorkspaces.qml` / `PillWorkspacesSide.qml` → indicadores de workspaces (el lateral
    usa el namespace `oozeshell-pill-workspaces`)
- IPC: sin target propio. Se interactúa con la píldora a través de los targets que redirigen según el
  modo: `menu toggle` (abre la sección `quickaccess` del dashboard), `notify toggle` (lista de avisos de
  la píldora), `audio`, `agenda`, `mpris`, `performance` y `powermenu`. Ver SHELL.md para la
  tabla completa y DASHBOARD.md para el mapa de secciones por modo.
- Estado y datos: `COMMON/AppState.qml` (`dashboardOpen`, `dashboardScreen`, `dashboardSection`,
  `pillAutoHide`, `pillHiddenNow`, `pillTraySync`, `trayVisible`). Ojo: las notificaciones de la píldora
  usan su propio `notifyOpen`/`notifyScreen` locales, no el centro de notificaciones de la barra.
- Dependencias: `COMMON` (AppState, WM, Theme), `Services/Lang`, `Modules/Taskbar`, `Modules/Tray`,
  `Modules/Dashboard`, `Services/Notify` y `Services/Mpris` (solo `PillMedia.qml`).
- Notas: con `pillAutoHide` la píldora se oculta y deja una zona de disparo (`triggerH`); `reserveZone`
  compensa `AppState.gapsOut`. La sección de avisos del dashboard no existe en este modo (ver
  DASHBOARD.md) precisamente porque la píldora ya trae la suya.
