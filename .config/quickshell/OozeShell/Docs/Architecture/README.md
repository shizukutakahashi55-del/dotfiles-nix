# OozeShell — documentación de arquitectura

Guías de `OozeShell/`, un shell de escritorio en Quickshell/QML. Una guía por módulo o servicio.
Las rutas se citan **desde la raíz del proyecto** (`Modules/…`, `Services/…`, `COMMON/…`).

## Estructura

| Carpeta | Qué contiene |
|---|---|
| `shell.qml` | raíz del shell: estado global de popups, montaje perezoso de paneles y los `IpcHandler` (ver SHELL.md) |
| `COMMON/` | singletons compartidos (`Theme`, `WM`, `AppState`, `ModeRuntime`, `Motion`, `OozeIcons`…) y componentes base (ventanas, rectángulos, pixel-art, barra) |
| `Core/` | infraestructura: `Core/Ipc/` (un handler por target), `CompositorPlatform`, `ConfigService`, `StateStore` |
| `Modules/` | superficies visibles: `Bar/`, `Pill/`, `Dashboard/`, `Power/`, `Lock/`, `Widgets/`, `Overview/`, `SystemMonitor/`, `Taskbar/`, `Tray/`, `Dock/`, `Privacy/`, `Keybinds/`, `Appearance/`, `QuickBar/` |
| `Services/` | backends y estado (agenda, audio, red, bluetooth, brillo, batería, mpris, notificaciones, wallpapers, lanzadores, apps, portapapeles, monitor, caffeina, caps, idioma) y sus popups |
| `Settings/` | panel de ajustes: registro de páginas (`SettingsRegistry`) y widgets de ajuste (`Settings/`, `Settings/pages/`) |
| `Backends/` | fachadas de métricas del equipo con núcleo nativo (C++) o respaldo QML/Python (ver CORE.md) |
| `native/` | módulo C++ `OozeShell.Native` + `native/shell.nix` |
| `Assets/` | fuentes y logos empaquetados |
| `Tools/` | scripts de desarrollo y diagnóstico (ver TOOLS.md) |
| `Docs/` | esta documentación |

## Guías

| Guía | Cubre |
|---|---|
| SHELL.md | `shell.qml`: estado de popups, montaje, tabla completa de targets IPC |
| CORE.md | `Core/` (IPC, plataforma, config, estado), `Backends/` y `native/` |
| COMMON.md | singletons y componentes compartidos, orden de capas |
| BAR.md | barra por pantalla, islas, marco, picker de módulos |
| PILL.md | píldora (modo píldora) |
| DASHBOARD.md | dashboard de barra y píldora, secciones y cabecera |
| OVERVIEW.md | cuadrícula de todas las ventanas (IPC `overview`) |
| SYSTEMMONITOR.md | ventana de aplicación de métricas (IPC `sysmon`) |
| POWER.md | menú de energía + batería |
| LOCK.md | pantalla de bloqueo |
| WIDGETS.md | widgets de escritorio |
| SETTINGS.md | panel de ajustes |
| APPEARANCE.md | apariencia del compositor (huecos, bordes, blur, sombras) |
| AUDIO.md · MPRIS.md · NETWORK.md · NOTIFY.md · AGENDA.md · MONITOR.md | servicios |
| LAUNCHER.md · DEFAULTAPPS.md | lanzadores, apps predeterminadas y `oozeshell` |
| WALLS.md | wallpapers (local, animado, online, esquemas) |
| TOOLS.md | scripts de `Tools/` |
| FONTS.md | fuentes del shell (`Docs/FONTS.md`) |

Sin guía propia (se explican en su cabecera y en BAR.md): `Modules/Taskbar/`, `Modules/Tray/`,
`Modules/Dock/`, `Modules/Privacy/`, `Modules/Keybinds/`.

## Convenciones

- **Rutas** de esta documentación: siempre desde la raíz del proyecto.
- **Comentarios**: en el código solo la cabecera del archivo (`// MÓDULO — nombre` y, si toca,
  `// IPC: target="…"`) y los nombres de sección.
- **IPC**: cada target tiene un archivo en `Core/Ipc/` con forma `Core/Ipc/<Nombre>Ipc.qml` y la
  cabecera `// CORE — <Nombre>Ipc` + `// IPC: target="…" funciones`. Los tres que no viven ahí son
  `apps` (`Services/DefaultApps/DefaultAppsHost.qml`), `quickbar` (`Modules/QuickBar/QuickBarHost.qml`)
  y `widgets` (`Modules/Widgets/WidgetHost.qml`).
- **Estado**: preferencias del usuario en `~/.config/oozeshell/` (`ui.json`, `config.json`,
  `widgets.json`, `quickbar.json`, `todos.json`…); estado volátil en `~/.cache/oozeshell/state.json`.
- **Dependencias**: `COMMON/` no importa a ningún módulo; los módulos importan `COMMON`, `Services` y
  `Modules` con rutas relativas (`../../COMMON`).
- **Núcleo nativo**: opcional. Sin `QML_IMPORT_PATH` apuntando al prefijo instalado, las fachadas de
  `Backends/` caen a su respaldo QML/Python sin error.
