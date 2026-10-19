# CORE — infraestructura: IPC, plataforma, configuración y estado

- Qué es: la capa base del shell. `Core/Ipc/` contiene un handler por target IPC; `Core/` los tres
  singletons de infraestructura. `Backends/` son las fachadas de métricas del equipo (con núcleo nativo
  opcional) y `native/` es el módulo C++ `OozeShell.Native`.

## IPC (`Core/Ipc/`)

- Un archivo por target: `Core/Ipc/<Nombre>Ipc.qml`, con la cabecera `// CORE — <Nombre>Ipc` y la línea
  `// IPC: target="…" funciones`.
- Contrato común: cada handler es un `Item` con `property var shell`; `shell.qml` los instancia en su
  bloque inicial (`import "Core/Ipc"` + una línea por handler). Tres reciben dependencias extra:
  `CapsIpc` (`capsOsd`), `LayoutOsdIpc` (`layoutOsd`), `OsdIpc` (`toastOsd`), `ClipboardIpc` (`history`)
  y `LockIpc` (`lockScreen`).
- Los targets que **no** viven aquí: `apps` (`Services/DefaultApps/DefaultAppsHost.qml`), `quickbar`
  (`Modules/QuickBar/QuickBarHost.qml`) y `widgets` (`Modules/Widgets/WidgetHost.qml`).
- La tabla completa de targets está en SHELL.md.

## Singletons (`Core/`)

| Archivo | Rol |
|---|---|
| `Core/CompositorPlatform.qml` | `wm` / `detectedWm`, `isHyprland` / `isNiri` / `isMango`, `has(cap)` (delega en `WM`) y `get()` / `set(id)` para cambiar de WM |
| `Core/ConfigService.qml` | preferencias de plataforma en `~/.config/oozeshell/config.json` (`wmPref`, `distroPref`, `pkgHelperPref`); migra el antiguo `wm.json` |
| `Core/StateStore.qml` | estado clave/valor en `~/.cache/oozeshell/state.json`: `common` (monitor, lang, corners, appearance, dnd, dockPins…) y `perWm`; `get/set/setCommon/getState/setWm` + `migrateLegacy()` |

- `StateStore` sustituye a los antiguos ficheros sueltos `~/.cache/oozeshell-monitor`, `-lang`,
  `-corners`, `-appearance.json`, `-dnd`, `-dock-pins` (se migran una vez). Es la fuente para
  `shell.qml` (monitor, idioma, esquinas), `Modules/Dock/DockBackend.qml` (pins) y
  `Services/Notify/NotificationsBackend.qml` (no molestar).
- `CompositorPlatform` importa `../COMMON` porque delega en `WM`; sin ese import `wm`/`detectedWm`
  caían al valor de respaldo (`"hyprland"`/`""`) y `set()` no llegaba nunca a `WM.setWm`.
- Los targets `wm`, `config` y `state` los registran `Core/Ipc/WmIpc.qml`, `ConfigIpc.qml` y
  `StateIpc.qml`; `native` lo registra `Core/Ipc/NativeIpc.qml` sobre `Backends/native/NativeSpec.qml`.
  Los cuatro son de solo lectura salvo `wm set <hyprland|niri|mango|auto>`, que persiste la preferencia
  (`WM.setWm` → `~/.config/oozeshell/config.json`).

## Backends (`Backends/`)

- Fachadas con núcleo nativo opcional: usan `OozeShell.Native` (C++) si está compilado y, si no,
  delegan en su respaldo QML (`Modules/Menu/SystemStats.qml`) o de sistema (`ps`). La UI no distingue.
- Unidades homogéneas: porcentajes `0..100` y `gpu = -1` cuando no hay GPU.
- Coste cero si nadie los pide: registro por referencia con `setWanted(clave, on)`; `wanted` es falso
  cuando no queda ningún cliente.
- `Backends/qmldir` declara los singletons `SystemMonitor` y `ProcessList`.

| Fachada | Respaldo | API principal |
|---|---|---|
| `Backends/SystemMonitor.qml` | nativo / QML | `cpu`, `cores`, `cpuTemp`, `cpuFreqMhz`, `ram`, `ramUsedMb`/`ramTotalMb`, `swap`, `load1/5/15`, `gpu`, `gpuAvailable`, `gpuName`, discos + `diskRate(nombre)`, red (`down`/`up`/`iface`), `intervalMs`, `maxSamples`, `backend` |
| `Backends/ProcessList.qml` | nativo / `ps` | `rows` (ordenadas por `sortBy` en la propia fachada), `total`, `numCores`, `cpuTotal`, `memTotalMb`, `intervalMs`, `limit`, `sortBy`, `kill(pid, sig)`, `backend`; `cpu` de cada fila usa escala `top` (100 = un núcleo) |
| `Backends/native/NativeSpec.qml` | — | módulos nativos activos y planificados (`get()`) |

- `Backends/python/ooze-daemon.py` es la herramienta única para trabajo pesado: modo servidor
  (JSON por stdin) y modo one-shot (`nix-search`, `palette`); siempre imprime un único documento JSON.

## Núcleo nativo (`native/`)

- Fuentes en `native/AnimationController/` (CMake): `AnimationController`, `FontProbe`, `SystemStats`,
  `SystemMonitor`, `ProcessList`, `WmStream` y `ActiveSource` (base interna). Se compilan como el
  módulo QML `OozeShell.Native`.
- `native/shell.nix` da el entorno de compilación en NixOS: la Qt del entorno debe ser la misma que usa
  `quickshell` (mismo hash en `/nix/store`) o Qt rechaza el plugin.
- Compilar e instalar: `bash Tools/build-native.sh [PREFIJO]` (por defecto
  `~/.local/share/oozeshell/qml`); compila en `native/AnimationController/build` y copia a
  `<PREFIJO>/OozeShell/Native/`. `Tools/ooze-run.sh build` hace lo mismo entrando en `nix-shell` si
  falta `cmake`.
- Al arrancar, el shell loguea `[theme] núcleo nativo: activo` cuando el módulo está disponible;
  `Tools/ooze-run.sh backends` dice qué hay compilado y qué respaldos se usan.
