# DASHBOARD — panel central desplegable de la píldora con secciones conmutables

- Qué es: contenedor (`Dashboard.qml`) que vive dentro de `PILL/Pill.qml` y muestra una sección a la vez (power, mpris, performance, audio, calendar, quickaccess, overview). En modo píldora (`Theme.pillMode`) varios IPC (mpris, menu, audio, powermenu, overview) se redirigen a secciones del dashboard en vez de abrir popups propios.
- Archivos:
  - `DASHBOARD/Dashboard.qml` → contenedor, orden de secciones (`sectionOrder`), transición entre ranuras y reenvío de teclas
  - `DASHBOARD/DashboardHeader.qml` → cabecera con selector de sección
  - `DASHBOARD/DashboardPower.qml` → sección de energía/sesión
  - `DASHBOARD/DashboardMpris.qml` → sección de reproductor (reutiliza `MPRIS`)
  - `DASHBOARD/DashboardPerformance.qml` → sección CPU/RAM/GPU (reutiliza `MENU`)
  - `DASHBOARD/DashboardAudio.qml` → sección de audio (reutiliza `AUDIO`)
  - `DASHBOARD/DashboardCalendar.qml` → sección calendario/agenda (reutiliza `AGENDA`)
  - `DASHBOARD/DashboardQuickAccess.qml` → accesos rápidos (red, bluetooth, brillo)
  - `DASHBOARD/DashboardOverview.qml` → vista de workspaces/ventanas embebida
- IPC: sin target propio. Se controla indirectamente vía `AppState` o los IPC que redirigen a él en modo píldora:
  - `menu toggle`, `mpris toggle`, `overview toggle/open/close` (ver `MENU.md`, `MPRIS.md`, `LAUNCHER.md`)
- Estado y datos: `AppState` (`pragma Singleton` en `COMMON/AppState.qml`): `dashboardOpen`, `dashboardScreen`, `dashboardSection`. Sin JSON ni caché propios.
- Dependencias: `../COMMON` (Theme, AppState, WM, OozeIcons), `../LANG`, y por sección `../MPRIS`, `../AUDIO`, `../MENU`, `../POWER`, `../BATTERY`, `../AGENDA`, `../NETWORK`, `../BLUETOOTH`, `../BRIGHTNESS`.
- Notas: `Pill.qml` precarga el dashboard (`warm`/`keepLoaded`) para que abrirlo no tenga retardo; el ancho/altura se adaptan a la sección visible (`preferredWidth`/`preferredHeight`).
