# WALLS — galería y aplicador de fondos

- Qué es
  - Galería de wallpapers estáticos, live (vídeo vía `mpvpaper`) y online (wallhaven/bing) con recolorado `matugen`. `Walls.qml` es un `Item` con `open` (no singleton); `Core/Ipc/ToggleWallsIpc.qml` lo alterna con el target `toggleWalls`.
  - Aplica con `awww img … --resize <wallFit> --fill-color <wallFillColor>` y recuerda el último en `~/.cache/awww/last`.
  - Motor elegible (Ajustes avanzados → Wallpapers): estáticos `awww` | `OozeWalls` (`Theme.wallStaticBackend`), live `mpvpaper` | `OozeWalls` (`Theme.liveBackend`). Con OozeWalls el shell llama `oozewalls apply <archivo> --output '*' --scaling fit|fill|stretch --no-palette` (la paleta sigue siendo la de `runMatugen`), el socket live pasa a `$XDG_RUNTIME_DIR/oozewalls/mpv_all.sock` y al arrancar (`bootRestore`, tras `Theme.wallsPrefsLoaded`) corre `oozewalls restore --only static|live`. Cambiar el motor reaplica el fondo actual.
- Archivos
  - `Services/Walls/Walls.qml` → lógica del módulo: modos `static/live/online/downloaded`, `wallpaperFolder/liveFolder`, `applyWallpaper/applyLive/applyOnline`, `runMatugen`, lector `~/.cache/awww/last`, IPC live `/tmp/oozeshell-live.sock`. Monta `FusedWindow` + `WallsPanel` y expone `compact`, `liveCount`, `onlineCount`, `downloadedCount`, `liveScanning`, `thumbsGenerating` para la UI.
  - `Services/Walls/WallsPanel.qml` → `FusedPanel` de la galería; elige borde, `faceOffset`, escala (`uiScale` = `Theme.wallsScale`) y cuerpo según `Theme.wallsLayout`. En `compact-top` es flotante (`detached`, sin fusión con la isla de la píldora) y deja un hueco de 10 px respecto a la barra, o solo al marco si la píldora se oculta sola.
  - `Services/Walls/WallsLayoutNormal.qml` → diseño `normal`: cabecera, tarjetas y paginador, panel abajo.
  - `Services/Walls/WallsLayoutCompact.qml` → diseño `compact-top`: panel pegado a la barra, una sola tira de selectores; va debajo de las tarjetas con la barra arriba y encima con la barra abajo.
  - `Services/Walls/WallsHeader.qml` → cabecera del diseño normal (4 burbujas).
  - `Services/Walls/WallsModeToggle.qml`, `WallsSchemeChips.qml`, `WallsSourceSwatches.qml`, `WallsActionChips.qml`, `WallsCounter.qml` → controles compartidos por ambos diseños (`compact`/tamaños por propiedad).
  - `Services/Walls/WallsCards.qml` + `WallsCard.qml` → carrusel de tarjetas y su delegado.
  - `Services/Walls/WallsPager.qml` → puntos + contador del diseño normal.
  - `Services/Walls/WallsFrameFlare.qml` → marco/animación al cambiar de fondo (`Theme.wallpaperChanging`, `frameCornerRadius`).
- IPC (Core/Ipc/ToggleWallsIpc.qml, target `toggleWalls`):
  | función | efecto |
  |---|---|
  | `handle` | alterna `wallsOpen` (abre/cierra la galería) |

  ```bash
  quickshell ipc -p .../shell.qml call -- toggleWalls handle
  ```
- Estado y datos
  - Sin singleton ni JSON propio: carpetas y ajustes (`wallpaperDir`, `liveWallpaperDir`, `wallFit`, `wallFillColor`, `wallsLayout` (`normal` | `compact-top`), `wallsScaleNormal`/`wallsScaleCompact` (50–150 %, escala todo el panel incluida la fuente, un tamaño por diseño; `Theme.wallsScale` devuelve el del activo; Ajustes → Wallpapers → Galería), `live*`, `online*`, `defaultSchemeIndex`, `schemes`, `paletteMode`) se leen de `Theme` (`~/.config/oozeshell/ui.json`).
  - Caché en `~/.cache/`: `awww/last` (fondo actual), `oozeshell/live/` + `live-active` + `live-player.log`, `oozeshell/live/opt` (copias optimizadas ffmpeg).
  - `indexMemory` (índice por modo) y `currentIndex` son memoria de sesión; `thumbRev` invalida miniaturas.
- Dependencias
  - `Theme` para toda la configuración; backends externos: `awww`, `mpvpaper` + `mpv` (live, con `socat` al socket), `ffmpeg` (optimización), `matugen` (paletas), script online (`curl`/`jq`).
  - `PowerProfile` (`power-saver` pausa el live), `WidgetConfig.raise` para capas sobre el fondo.
- Notas
  - `targetScreen` por defecto es `"DP-3"` (fijo en código), no el monitor enfocado.
  - `onlineApiKey` viaja como `OOZE_WH_KEY` al script y se guarda en texto plano en `ui.json` (aviso visible en la interfaz).

## Animación de cambio

Ajustes → Wallpapers → "Animación al cambiar de fondo".

- Preferencias en `Theme.qml`: `wallTransition` (14 tipos, por defecto `fade`) y `wallTransitionMs` (100–3000, por defecto 600). Se guardan con el resto de `wallsPrefs`.
- `Walls.qml`, bloque "Transiciones":
  - `oozeTransitionArgs(animate)` añade `--transition` y `--transition-duration` (o `--no-transition`) a `oozewalls apply`.
  - `awwwTransitionArgs(animate)` traduce el tipo a `--transition-type` de awww.
  - `liveReplaceKillCmd` evita matar el video anterior cuando OozeWalls ya tiene su socket, para que pueda animar la salida.
- Anima: cambio de wallpaper estático y de video. No anima: reajuste de ajuste (fit) y relanzado automático del video por RAM o energía.
- Con el backend `mpvpaper` independiente no hay animación de video.
- Detalle del motor: `OozeWalls/docs/TRANSICIONES.md`.
- `transitionHoldMs` (cuánto tiempo la barra y el marco quedan en modo "cambiando") sigue la duración elegida más 300 ms; con "sin animación" es 400 ms.

## Página de ajustes (Ajustes avanzados → Wallpapers)

`Settings/pages/WallpapersPage.qml`, orden de secciones:

| Sección | Contenido |
|---|---|
| Carpetas | estáticos, live y descargas online |
| Galería | diseño y tamaño |
| Imágenes y animación | motor, ajuste, color de bandas, tipo y duración de la animación |
| Wallpapers en vivo | motor, ajuste, capa, decodificación |
| En vivo · ahorro de recursos | copia liviana, alto y fps máximos, parar si no se ve, tope de RAM |
| Wallpapers en línea | fuente, búsqueda, orden, categorías, resolución, contenido, API key |
| Paleta (matugen) | esquema |
| Herramientas | estado de las dependencias |

Componentes locales: `ChipRow`, `StepRow`, `SwitchRow`, `TextRow`, `FolderEntry`, `Duo` (dos controles lado a lado) y `Divider`.

Las ayudas solo se muestran donde el nombre de la opción no basta (motores, capa, ahorro, filtros de contenido, API key). Cada sección y fila está en `SettingsRegistry.qml` para el buscador; al añadir una opción hay que añadirla también ahí.

