# WALLS — galería y aplicador de fondos

- Qué es
  - Galería de wallpapers estáticos, live (vídeo vía `mpvpaper`) y online (wallhaven/bing) con recolorado `matugen`. `Walls.qml` es un `Item` con `open` (no singleton); `Core/Ipc/ToggleWallsIpc.qml` lo alterna con el target `toggleWalls`.
  - Aplica con `awww img … --resize <wallFit> --fill-color <wallFillColor>` y recuerda el último en `~/.cache/awww/last`.
  - Motor elegible (Ajustes avanzados → Wallpapers): estáticos `awww` | `OozeWalls` (`Theme.wallStaticBackend`), live `mpvpaper` | `OozeWalls` (`Theme.liveBackend`). Con OozeWalls el shell llama `oozewalls apply <archivo> --output '*' --scaling fit|fill|stretch --no-palette` (la paleta sigue siendo la de `runMatugen`), el socket live pasa a `$XDG_RUNTIME_DIR/oozewalls/mpv_all.sock` y al arrancar (`bootRestore`, tras `Theme.wallsPrefsLoaded`) corre `oozewalls restore --only static|live`. Cambiar el motor reaplica el fondo actual.
- Archivos
  - `Services/Walls/Walls.qml` → lógica del módulo: modos `static/live/online/downloaded`, `wallpaperFolder/liveFolder`, `applyWallpaper/applyLive/applyOnline`, `runMatugen`, lector `~/.cache/awww/last`, IPC live `/tmp/oozeshell-live.sock`. Monta `FusedWindow` + `WallsPanel` y expone `compact`, `liveCount`, `onlineCount`, `downloadedCount`, `liveScanning`, `thumbsGenerating` para la UI.
  - `Services/Walls/WallsPanel.qml` → `FusedPanel` de la galería; elige borde, `faceOffset`, escala (`uiScale` = `Theme.wallsScale`) y cuerpo según `Theme.wallsLayout`. En `compact-top` es flotante (`detached`, sin fusión con la isla de la píldora) y deja un hueco de 10 px respecto a la barra, o solo al marco si la píldora se oculta sola.
  - `Services/Walls/WallsLayoutNormal.qml` → diseño `normal`: buscador, tarjetas y barra de controles (modo, esquemas, acciones, contador), panel abajo.
  - `Services/Walls/WallsLayoutCompact.qml` → diseño `compact-top`: panel pegado a la barra, buscador y tira de controles (escalada si no cabe); va debajo de las tarjetas con la barra arriba y encima con la barra abajo.
  - `Services/Walls/WallsHeader.qml` → cabecera del diseño normal (4 burbujas).
  - `Services/Walls/WallsModeToggle.qml`, `WallsSchemeChips.qml`, `WallsSourceSwatches.qml`, `WallsActionChips.qml`, `WallsCounter.qml` → controles compartidos por ambos diseños (`compact`/tamaños por propiedad).
  - `Services/Walls/WallsSchemeChips.qml` muestra los esquemas en el orden de `Theme.schemeOrder` (vivos → fieles → apagados) sin tocar los índices guardados (`schemeIndex` sigue siendo el de `Theme.schemes`). Con `columns > 0` usa celdas iguales en cuadrícula (el rail usa `Theme.schemeColumns`); sin él, chips a su ancho como antes. `Settings/pages/WallpapersPage.qml` usa el mismo orden.
  - `Services/Walls/WallsSearchBar.qml` → campo de búsqueda (Ctrl+K o `/`), selector Imágenes/Live (solo Online), botones Filtros y Orden; maneja el teclado mientras el campo tiene foco.
  - `Services/Walls/WallsPopup.qml` → menú de Filtros / Orden según el modo; `WallsBarButton.qml` y `WallsKindToggle.qml` son sus controles.
  - `Services/Walls/WallsCards.qml` + `WallsCard.qml` → tira de tarjetas (central ancha, laterales recortadas, `cardRatio` 0.34 normal / 0.30 compacto) y su delegado; en Online la tarjeta central carga la imagen original tras 450 ms.
  - `Services/Walls/WallsFrameFlare.qml` → marco/animación al cambiar de fondo (`Theme.wallpaperChanging`, `frameCornerRadius`).
- IPC (Core/Ipc/ToggleWallsIpc.qml, target `toggleWalls`):
  | función | efecto |
  |---|---|
  | `handle` | alterna `wallsOpen` (abre/cierra la galería) |

  ```bash
  quickshell ipc -p .../shell.qml call -- toggleWalls handle
  ```
- Estado y datos
  - Sin singleton ni JSON propio: carpetas y ajustes (`wallpaperDir`, `liveWallpaperDir`, `wallFit`, `wallFillColor`, `wallsLayout` (`normal` | `compact-top`), `wallsScaleNormal`/`wallsScaleCompact` (50–150 %, escala todo el panel incluida la fuente, un tamaño por diseño; `Theme.wallsScale` devuelve el del activo; Ajustes → Wallpapers → Galería), `live*`, `online*`, `defaultSchemeIndex`, `schemes`, `paletteMode`) se leen de `Theme` (`~/.config/oozeshell/ui.toml`).
  - Caché en `~/.cache/`: `awww/last` (fondo actual), `oozeshell/live/` + `live-active` + `live-player.log`, `oozeshell/live/opt` (copias optimizadas ffmpeg).
  - `indexMemory` (índice por modo) y `currentIndex` son memoria de sesión; `thumbRev` invalida miniaturas.
- Dependencias
  - `Theme` para toda la configuración; backends externos: `awww`, `mpvpaper` + `mpv` (live, con `socat` al socket), `ffmpeg` (optimización), `matugen` (paletas), script online (`curl`/`jq`).
  - `PowerProfile` (`power-saver` pausa el live), `WidgetConfig.raise` para capas sobre el fondo.
- Notas
  - `targetScreen` por defecto es `"DP-3"` (fijo en código), no el monitor enfocado.
  - `onlineApiKey` viaja como `OOZE_WH_KEY` al script y se guarda en texto plano en `ui.toml` (aviso visible en la interfaz).

## Búsqueda, filtros y Online Live

- Estado en `Walls.qml`, bloque "Búsqueda, filtros y orden": `searchText`, `filterExt`, `sortLocal`, `popup`. En Static, Live y Descargas se filtra por nombre al escribir y `activeModel` pasa a `viewModel` (copia filtrada y ordenada); en Online con Wallhaven o los sitios live el texto se envía como `onlineQuery` (tras 850 ms o con Enter); con Bing se filtra en local.
- Orden local: nombre A-Z / Z-A, más nuevos / más viejos (usa `mtime` de `find -printf`). Orden online: el de `onlineSorting` (en live: recientes o relevancia).
- Teclado con el campo enfocado: Tab cambia de modo, ↑↓ y PgUp/PgDn navegan, ←/→ y Home/End navegan si el texto está vacío, Enter busca o aplica, Esc cierra menú → borra texto → cierra el selector, Ctrl+R aleatorio, Ctrl+P vista previa.
- Online → Live (`Theme.onlineKind = "live"`): fuentes Moewalls y WallpaperWaifu (API REST de WordPress, sin API key). El flujo completo está en la sección "Online Live: flujo y bloques" más abajo.
- Descargas lista imágenes y videos de la carpeta de descargas (incluida `Live/`); los videos se aplican como live.
- Ajustes → Wallpapers → "Wallpapers en línea · Live": fuente.

## Online Live: flujo y bloques

Tres momentos: **listar** (rápido, solo miniaturas), **previsualizar** (clips animados en segundo plano) y **aplicar** (descarga en la mejor calidad disponible).

```
Walls.qml (fetchOnline) ──► Tools/online-live.sh ──► filas por stdout
        │                                              │
        │                                              ▼
        │                                  onlineModel (ListModel)
        ├─► startOnlineClips ─► genOnlineClips ─► Tools/online-clip.sh ─► clips .gif
        └─► applyOnlineItem  ─► applyOnline    ─► Tools/online-download.sh
                                                         └─► Tools/online-resolve.sh
```

### 1. Listar — `Tools/online-live.sh`

Uso: `online-live.sh <fuente> <busqueda> <orden> <pagina> <dir miniaturas>`. Fuentes: `moewalls`, `wallpaperwaifu`.

- Consulta `/wp-json/wp/v2/posts` (18 por página). Si el sitio no responde 200 con un array, cae al HTML del sitio. Código de salida 3 si no hay red.
- Procesa los posts en paralelo (`ONLINE_LIVE_JOBS`, por defecto 8) y **emite las filas en el orden del sitio apenas están listas**, sin esperar a las lentas.
- Separa los videos del post en dos grupos: el principal y los de vista previa (nombres con `preview`, `sample`, `thumb` o `poster`). Antes se tomaba el primer `.mp4`, que muchas veces era la vista previa de baja calidad.
- Guarda en `~/.cache/oozeshell/online/meta/` el video, título y vista previa de cada post, así que volver a abrir una página ya vista no consulta el sitio otra vez. Las miniaturas quedan en `online/thumbs/`.
- Separador interno de campos: `\037` (no tabulador, para no perder campos vacíos).
- Salida, una línea por wallpaper, separada por tabuladores:

| # | Campo | Uso en `Walls.qml` |
|---|---|---|
| 1 | nombre de archivo | `name`/destino en `<descargas>/Live/` |
| 2 | URL del video (o del post si no se encontró) | `url` |
| 3 | miniatura local | `thumb` |
| 4 | título · fuente | `name` visible |
| 5 | URL del post | `page`, para resolver la mejor calidad |
| 6 | ruta del clip animado | `clip` |
| 7 | URL del video de vista previa | `pv` |

### 2. Previsualizar — `Tools/online-clip.sh` y `startOnlineClips`

- Al terminar cada página, `fetchOnline.onExited` llama a `startOnlineClips()`, que arma la lista `ruta<TAB>clip<TAB>url` de los items sin clip y se la pasa a `online-clip.sh` por heredoc (`OOZE_CLIPS`).
- `online-clip.sh <referer>` genera un GIF de 3 s, 320 px, 12 fps (`ONLINE_CLIP_JOBS`, por defecto 4 a la vez). Usa el video de vista previa del sitio (pequeño) y, si no hay, el principal. Si `ffmpeg` no puede leer la URL directamente, baja el archivo (máx. 80 MB) y lo convierte en local.
- Cada clip terminado se imprime por stdout; `genOnlineClips` marca `clipReady` y `WallsCard.qml` lo muestra en la tarjeta central con `AnimatedImage`. Mientras tanto la tarjeta muestra la miniatura.
- Si llega otra página mientras se generan clips, `rerun` encola una segunda pasada. Cambiar fuente, búsqueda u orden cancela el proceso.
- La vista previa respeta `previewOn` (Ctrl+P) y `Theme.shellPerf`.

### 3. Precarga de páginas

- Al terminar la página 1 de Online Live se pide la 2 automáticamente (`Qt.callLater(loadMoreOnline)`).
- Después se pide la siguiente cuando el cursor está a 8 tarjetas del final (antes 4).

### 4. Aplicar — `Tools/online-download.sh` y `Tools/online-resolve.sh`

`applyOnline` ejecuta `online-download.sh <fuente> <url> <destino> <post> <referer>` para videos:

1. `online-resolve.sh` abre la página del post y reúne candidatos: la URL ya conocida, todo `.mp4`/`.webm` del HTML y los enlaces de descarga. Descarta vistas previas.
2. Consulta las cabeceras (`HEAD`, 6 en paralelo) de cada candidato, conserva los que sean video y elige **el de mayor tamaño**, usando la resolución del nombre (`2160`, `1080`, `4k`…) como desempate. Devuelve `URL<TAB>bytes`.
3. Si el destino ya existe y pesa lo mismo o más, no se vuelve a bajar; si pesa menos (por ejemplo una descarga anterior de baja calidad) se reemplaza.
4. Descarga con `aria2c` (8 conexiones) si está instalado; si no, con `curl` con reanudación (`-C -`), reintentos y corte solo por velocidad mínima (ya no hay límite fijo de 300 s, que cortaba los 4K).
5. Solo entonces entra por `startVideo` (fotograma, matugen, mpvpaper/OozeWalls).

Si el sitio no expone ningún video, el script termina con código 1 y la tarjeta muestra el error de red.

### Calidad al reproducir

La descarga queda en su calidad original, pero `liveOptimize` (Ajustes → Wallpapers → En vivo · ahorro de recursos) crea una copia liviana limitada a `liveOptMaxHeight` (1080 por defecto) y `liveOptMaxFps` (30). Para un monitor 1440p o 4K hay que subir esos límites o desactivar la copia liviana; si no, el video se reproduce reducido aunque se haya bajado completo.

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
| Wallpapers en línea · Live | fuente (Moewalls / WallpaperWaifu) |
| Paleta (matugen) | esquema |
| Herramientas | estado de las dependencias |

Componentes locales: `ChipRow`, `StepRow`, `SwitchRow`, `TextRow`, `FolderEntry`, `Duo` (dos controles lado a lado) y `Divider`.

Las ayudas solo se muestran donde el nombre de la opción no basta (motores, capa, ahorro, filtros de contenido, API key). Cada sección y fila está en `SettingsRegistry.qml` para el buscador; al añadir una opción hay que añadirla también ahí.

