# WALLS — galería y aplicador de fondos

- Qué es
  - Galería de wallpapers estáticos, live (vídeo vía `mpvpaper`) y online (wallhaven/bing) con recolorado `matugen`. `Walls.qml` es un `Item` con `open` (no singleton); `shell.qml` lo alterna con el target `toggleWalls`.
  - Aplica con `awww img … --resize <wallFit> --fill-color <wallFillColor>` y recuerda el último en `~/.cache/awww/last`.
- Archivos
  - `WALLS/Walls.qml` → todo el módulo (~900 líneas): modos `static/live/online/downloaded`, `wallpaperFolder/liveFolder`, `applyWallpaper/applyLive/applyOnline`, `runMatugen`, lector `~/.cache/awww/last`, IPC live `/tmp/oozeshell-live.sock`.
  - `WALLS/WallsFrameFlare.qml` → marco/animación al cambiar de fondo (`Theme.wallpaperChanging`, `frameCornerRadius`).
- IPC
  | target | función | efecto |
  |---|---|---|
  | `toggleWalls` | `handle` | alterna `wallsOpen` (abre/cierra la galería) |

  ```bash
  quickshell ipc -p .../shell.qml call -- toggleWalls handle
  ```
- Estado y datos
  - Sin singleton ni JSON propio: carpetas y ajustes (`wallpaperDir`, `liveWallpaperDir`, `wallFit`, `wallFillColor`, `live*`, `online*`, `defaultSchemeIndex`, `schemes`, `paletteMode`) se leen de `Theme` (`~/.config/oozeshell/ui.json`).
  - Caché en `~/.cache/`: `awww/last` (fondo actual), `oozeshell/live/` + `live-active` + `live-player.log`, `oozeshell/live/opt` (copias optimizadas ffmpeg).
  - `indexMemory` (índice por modo) y `currentIndex` son memoria de sesión; `thumbRev` invalida miniaturas.
- Dependencias
  - `Theme` para toda la configuración; backends externos: `awww`, `mpvpaper` + `mpv` (live, con `socat` al socket), `ffmpeg` (optimización), `matugen` (paletas), script online (`curl`/`jq`).
  - `PowerProfile` (`power-saver` pausa el live), `WidgetBackdrop`/`WidgetConfig.raise` para capas sobre el fondo.
- Notas
  - `targetScreen` por defecto es `"DP-3"` (fijo en código), no el monitor enfocado.
  - `onlineApiKey` viaja como `OOZE_WH_KEY` al script y se guarda en texto plano en `ui.json` (aviso visible en los 4 idiomas).
