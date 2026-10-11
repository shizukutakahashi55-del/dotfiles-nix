# SHELL — raíz del shell (shell.qml)

`ShellRoot` que monta todo y concentra los `IpcHandler` (sección `// ─── IPC ───` al inicio, tras `id: root`).

- Qué es: estado global de popups, selección de monitor/idioma/esquinas, montaje perezoso de paneles y los 27 targets IPC.
- Montaje: cada panel cuelga de un `LazyPopup { wanted: root.xxxOpen }` (solo existe abierto) o `LazyLoader`. Por eso los IPC de launcher/nixsearch escriben `launcherStartMode` / `nixStartQuery` / `nixStartInstalled` ANTES de abrir.
- Superficies excluyentes: `Theme.pillMode` activa PÍLDORA (PILL + Dashboard vía `AppState`), si no BARRA (BAR + popups). `isBarOnlyPopup`: `overview`, `barsettings`. Los popups de barra son excluyentes (`closeAllPopupsExceptAdvanced`); Ajustes avanzados es el único que no se cierra solo.
- Monitor: `targetMonitor` (`"auto"` = pantalla bajo el mouse vía `resolveMonitor()`) + `focusedMonitor` (última pantalla tocada). Persistencia en `~/.cache/oozeshell-monitor`, `~/.cache/oozeshell-lang`, `~/.cache/oozeshell-corners`.

## IPC

Forma: `quickshell ipc -p .../shell.qml call -- <target> <funcion> [args]`

| target | funciones | ejemplo |
|---|---|---|
| corners | toggle, set, get | `corners toggle` |
| bar | position, togglePosition, floating, toggleFloating, islands, toggleIslands, pill, togglePill, get | `bar position bottom` · `bar toggleIslands` |
| monitor | set, get, togglePicker, list, current | `monitor set auto` · `monitor list` |
| lang | set, get, togglePicker, list | `lang set es` |
| settings | toggle, open, close, get, setUi, setLevel, reset | `settings toggle` · `settings setLevel font 4` |
| theme | mode, toggle, cycle, get, style(+Get), font(+Get), softfont(+Get), pixelfont(+Get), fonts, fontsrefresh, cozy, palette, cozywarm | `theme toggle` · `theme palette strawberry-milk` |
| appearance | toggle, get, set | `appearance set gapsOut 10` |
| toggleWalls | handle | `toggleWalls handle` |
| notify | toggle, show, toggleDnd, enableDnd, disableDnd, isDnd, clear, state | `notify toggle` · `notify show 'Titulo'` |
| agenda | toggle, open, close | `agenda toggle` |
| performance | toggle, set, get | `performance toggle` |
| keybinds | toggle | `keybinds toggle` |
| keyboardlayout | next | `keyboardlayout next` |
| mpris | toggle | `mpris toggle` |
| menu | toggle | `menu toggle` |
| network | toggle | `network toggle` |
| bluetooth | toggle | `bluetooth toggle` |
| audio | toggle, raise, lower, mute, micToggle, micRaise, micLower | `audio raise` · `audio mute` |
| caps / layoutosd / osd | show | `osd show` |
| clipboard | toggle, open, close | `clipboard toggle` |
| overview | toggle, open, close | `overview toggle` |
| launcher | toggle, open, close | `launcher toggle` |
| nixsearch | toggle, open, installed, close | `nixsearch installed` |
| screenshot | areaCopy, fullSave, areaSave | `screenshot areaCopy` |
| powermenu | toggle, open, close | `powermenu toggle` |
| lock | lock, locked | `lock lock` (ver LOCK.md) |

## Notas

- El handler `mpris` quedó junto a su `LazyPopup` (sangría de 4 espacios en el original) en vez de la sección IPC.
- En modo píldora varios toggles se redirigen a `AppState.toggleDashboard(...)`.
- Ver también: WIDGETS.md (`widgets ...`), LAUNCHER.md (`quickbar ...`).
