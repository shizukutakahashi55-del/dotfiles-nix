# LAUNCHER — lanzadores: Launcher (apps/ventanas/comandos), QuickBar (búsqueda/archivos) y PackageSearch (paquetes)

- Qué es: tres frontales de búsqueda/lanzamiento. `Launcher` es el lanzador completo por popup; `QuickBar` es una barra rápida minimalista con host e IPC propios; `PackageSearch` es el buscador de paquetes que se abre vía el target `nixsearch`.

## Launcher (`OozeShell/Launcher`)

- Archivos:
  - `Launcher/Launcher.qml` → UI principal, modos `apps | windows | run | files | commands | tmux`, lee `DesktopEntries.applications`
  - `Launcher/LauncherCommands.qml` → definición de comandos personalizados
  - `Launcher/TmuxSessions.qml` → listado de sesiones tmux vía `Process`
  - `Launcher/LauncherParticles.qml` → fondo decorativo de partículas
- IPC (`shell.qml`, target `launcher`):

  | Función | Efecto |
  |---|---|
  | `toggle` | alterna popup (modo `apps`); usa rofi si `useRofiLauncher()` |
  | `open <modo>` | abre en un modo (`apps`, `windows`, `run`, `files`, `commands`, `tmux`) |
  | `close` | cierra |

  ```sh
  quickshell ipc -p .../shell.qml call -- launcher toggle
  quickshell ipc -p .../shell.qml call -- launcher open windows
  quickshell ipc -p .../shell.qml call -- launcher close
  ```
- Estado y datos: sin singleton; prop `startMode`/`mode` en memoria. Lee caché `~/.cache/oozeshell/live*` y `~/.cache/awww/last` para fondos (líneas ~659-663 de `Launcher.qml`).
- Dependencias: `../COMMON`, `../LANG`, `Quickshell.Io` (`Process`, `DesktopEntries`).

## QuickBar (`OozeShell/QUICKBAR`)

- Archivos:
  - `QUICKBAR/QuickBarHost.qml` → `Scope` con estado abierto/cerrado, `LazyPopup` y el `IpcHandler` propio (target `quickbar`); lo instancia `shell.qml` (bloque `QuickBarHost`, `shell.qml:1412`)
  - `QUICKBAR/QuickBar.qml` → tarjeta de búsqueda (web con bangs + archivos con prefijo `f `)
  - `QUICKBAR/QuickBarConfig.qml` → `pragma Singleton` con ajustes y persistencia
- IPC (target `quickbar`, en `QuickBarHost.qml`):

  | Función | Efecto |
  |---|---|
  | `toggle` / `open` / `close` | alterna, abre, cierra |
  | `search <texto>` | abre con consulta inicial |
  | `files` | abre en modo archivos (`f `) |
  | `position <p>` | cambia posición vía `QuickBarConfig` |
  | `filesEnabled <bool>` | activa/desactiva búsqueda de archivos |
  | `get` | devuelve `QuickBarConfig.snapshot()` en JSON |

  ```sh
  quickshell ipc -p .../shell.qml call -- quickbar toggle
  quickshell ipc -p .../shell.qml call -- quickbar search 'nixpkgs firefox'
  quickshell ipc -p .../shell.qml call -- quickbar files
  quickshell ipc -p .../shell.qml call -- quickbar get
  ```
- Estado y datos: `QuickBarConfig` (`pragma Singleton`): `position`, `widthMode`, `browserId`, `engineId`, `bangsEnabled`, `filesEnabled`, `fileRoots`, `fileDepth`, etc. Persiste en `~/.config/oozeshell/quickbar.json` (`dir` + `file` en `QuickBarConfig.qml:41-42`).
- Dependencias: `../COMMON`, `../LANG`.

## PackageSearch (`OozeShell/PackageSearch`)

- Archivos:
  - `PackageSearch/PackageSearch.qml` → buscador unificado; backend según `WM.packageBackend`
  - `PackageSearch/installed.sh` → helper para listar paquetes instalados (modo `installed`)
- IPC (`shell.qml`, target `nixsearch`):

  | Función | Efecto |
  |---|---|
  | `toggle` | alterna buscador |
  | `open [consulta]` | abre con consulta inicial |
  | `installed` | abre en modo paquetes instalados |
  | `close` | cierra |

  ```sh
  quickshell ipc -p .../shell.qml call -- nixsearch toggle
  quickshell ipc -p .../shell.qml call -- nixsearch open 'firefox'
  quickshell ipc -p .../shell.qml call -- nixsearch installed
  quickshell ipc -p .../shell.qml call -- nixsearch close
  ```
- Estado y datos: sin singleton; `backend` = `WM.packageBackend` (`COMMON/WM.qml:64-69`: `nix-search` en NixOS, si no `pkgHelperPref` o primer helper disponible, por defecto `pacman`). Requiere binario `nix-search` cuando el backend es nix (emite `__NO_NIX_SEARCH__` si falta).
- Dependencias: `../COMMON` (WM), `../LANG`.
- Notas: el nombre del target IPC (`nixsearch`) es histórico; en Arch el backend real es pacman/AUR, no nix.
