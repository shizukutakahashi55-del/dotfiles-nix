# SHELL — raíz del shell (shell.qml)

`ShellRoot` que monta todo. Los `IpcHandler` **ya no viven aquí**: cada target tiene su archivo en
`Core/Ipc/` y `shell.qml` solo los instancia (`import "Core/Ipc"` + `CornersIpc { shell: root }`, …).

- Qué es: estado global de popups, selección de monitor/idioma/esquinas, montaje perezoso de paneles y
  los 37 targets IPC (34 en `Core/Ipc/`, 3 en su host).
- Montaje: cada panel cuelga de un `LazyPopup { wanted: root.xxxOpen }` (solo existe abierto) o de un
  `LazyLoader`. Por eso los IPC de launcher/nixsearch escriben `launcherStartMode` / `nixStartQuery` /
  `nixStartInstalled` **antes** de abrir.
- Superficies excluyentes: con `Theme.pillMode` manda la píldora (`Modules/Pill`, dashboard vía
  `AppState`) y sin él manda la barra (`Modules/Bar` + popups). `isBarOnlyPopup`: `barsettings`. Los popups de barra son excluyentes (`closeAllPopupsExceptAdvanced`); Ajustes avanzados
  es el único que no se cierra solo.
- Monitor: `targetMonitor` (`"auto"` = pantalla bajo el ratón, vía `resolveMonitor()`) y
  `focusedMonitor` (última pantalla tocada). La persistencia de monitor, idioma, esquinas, apariencia,
  «no molestar» y pins del dock está en `Core/StateStore.qml` (`~/.cache/oozeshell/state.json`), que
  migró los antiguos `~/.cache/oozeshell-monitor`, `-lang`, `-corners`, `-appearance.json`, `-dnd` y
  `-dock-pins`.
- `root.menuOpen` deriva de `AppState.dashboardOpen` cuando la barra está activa, para que el botón del
  menú marque el estado del dashboard.

## IPC

Forma: `quickshell ipc -c OozeShell call -- <target> <funcion> [args]` (o el atajo `oozeshell`).

En `Core/Ipc/`:

| target | archivo | funciones | ejemplo |
|---|---|---|---|
| corners | `CornersIpc.qml` | toggle, set, get | `corners toggle` |
| bar | `BarIpc.qml` | position, togglePosition, floating, toggleFloating, floatWindows, toggleFloatWindows, windowAnim, cycleWindowAnim, hidden, toggleHidden, hiddenFrame, revealMode, peek, islands, toggleIslands, pill, togglePill, templates, templateSave, templateLoad, templateDelete, get | `bar position bottom` · `bar toggleIslands` |
| monitor | `MonitorIpc.qml` | set, get, list, current, togglePicker | `monitor set auto` · `monitor list` |
| lang | `LangIpc.qml` | set, get, list, togglePicker | `lang set es` |
| settings | `SettingsIpc.qml` | toggle, open, close, get, setUi, setLevel, setSize, reset, resetWindow | `settings toggle` · `settings setLevel font 4` |
| theme | `ThemeIpc.qml` | mode, toggle, cycle, get, style, styleGet, font, fontGet, softfont, softfontGet, pixelfont, pixelfontGet, fonts, fontsrefresh, cozy, cozywarm, palette | `theme toggle` · `theme palette strawberry-milk` |
| appearance | `AppearanceIpc.qml` | toggle, set, get | `appearance set gapsOut 10` |
| toggleWalls | `ToggleWallsIpc.qml` | handle | `toggleWalls handle` |
| notify | `NotifyIpc.qml` | toggle, show, toggleDnd, enableDnd, disableDnd, isDnd, clear, state | `notify toggle` · `notify show 'Titulo'` |
| agenda | `AgendaIpc.qml` | toggle, open, close | `agenda toggle` |
| performance | `PerformanceIpc.qml` | toggle, set, get, getScope, setScope | `performance toggle` |
| keybinds | `KeybindsIpc.qml` | toggle | `keybinds toggle` |
| keyboardlayout | `KeyboardLayoutIpc.qml` | next | `keyboardlayout next` |
| mpris | `MprisIpc.qml` | toggle | `mpris toggle` |
| menu | `MenuIpc.qml` | toggle | `menu toggle` |
| network | `NetworkIpc.qml` | toggle | `network toggle` |
| bluetooth | `BluetoothIpc.qml` | toggle | `bluetooth toggle` |
| caffeine | `CaffeineIpc.qml` | toggle, set, get | `caffeine toggle` |
| audio | `AudioIpc.qml` | toggle, raise, lower, mute, micToggle, micRaise, micLower | `audio raise` · `audio mute` |
| caps | `CapsIpc.qml` | show | `caps show` |
| layoutosd | `LayoutOsdIpc.qml` | show | `layoutosd show` |
| osd | `OsdIpc.qml` | show | `osd show` |
| clipboard | `ClipboardIpc.qml` | toggle, open, close | `clipboard toggle` |
| overview | `OverviewIpc.qml` | toggle, open, close | `overview toggle` (cuadrícula de ventanas; nativo en Niri) |
| launcher | `LauncherIpc.qml` | toggle, open, close | `launcher toggle` |
| nixsearch | `NixSearchIpc.qml` | toggle, open, installed, close | `nixsearch installed` |
| screenshot | `ScreenshotIpc.qml` | areaCopy, areaSave, fullSave | `screenshot areaCopy` |
| powermenu | `PowerMenuIpc.qml` | toggle, open, close | `powermenu toggle` |
| lock | `LockIpc.qml` | lock, locked, set, get, reset | `lock lock` (ver LOCK.md) |
| sysmon | `SystemMonitorIpc.qml` | open, close, toggle, section, isOpen, backend | `sysmon toggle` (ver SYSTEMMONITOR.md) |
| wm | `WmIpc.qml` | get, set | `wm get` · `wm set niri` |
| config | `ConfigIpc.qml` | get | `config get` |
| state | `StateIpc.qml` | get | `state get` |
| native | `NativeIpc.qml` | get | `native get` |

Fuera de `Core/Ipc/` (los registra su propio host):

| target | archivo | funciones | ejemplo |
|---|---|---|---|
| apps | `Services/DefaultApps/DefaultAppsHost.qml` | open, openWith, any, url, urlPrivate, file, dir, term, set, sysset, sysget, custom, get, list, state | `apps open browser` · `apps dir ~/Descargas` |
| quickbar | `Modules/QuickBar/QuickBarHost.qml` | toggle, open, close, position, search, files, filesEnabled, get | `quickbar toggle` |
| widgets | `Modules/Widgets/WidgetHost.qml` | add, remove, enable, disable, toggle, style, move, size, monitor, option, pomodoro, layer, edit, raise, list, types, arrange, freemove, border, quick | `widgets list` (ver WIDGETS.md) |

## Notas

- Listar todo lo disponible: `oozeshell list` o `quickshell ipc -c OozeShell show`.
- En modo píldora varios toggles se redirigen a `AppState.toggleDashboard(...)`: `menu` (accesos
  rápidos), `audio`, `agenda`, `mpris` y `powermenu`.
- Los `IpcHandler` de `Core/Ipc/` reciben `property var shell`; algunos reciben además su dependencia
  (`capsOsd`, `layoutOsd`, `toastOsd`, `history`, `lockScreen`).
- Ver también: DASHBOARD.md, PILL.md, WIDGETS.md, LAUNCHER.md (`quickbar`, `nixsearch`),
  DEFAULTAPPS.md (`apps`), CORE.md y SYSTEMMONITOR.md (`sysmon`).
