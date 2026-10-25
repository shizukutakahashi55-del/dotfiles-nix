# OozeWalls — arquitectura simple

Motor mínimo de wallpapers para Wayland. `mpvpaper` hace el render;
`oozewalls` es un controlador sin estado. Quickshell manda, nunca al revés.

## Capas

| Capa | Qué es | RAM |
|---|---|---|
| L0 `mpvpaper` + `mpv` | Único proceso que pinta. Un socket por salida. | 150-500 MB solo con video activo |
| L1 `oozewalls` CLI | Sin daemon residente. Cada llamada lee config, habla al socket o lanza `mpvpaper`. | 0 MB en reposo |
| L2 `oozewalls-gui` | App nativa standalone (egui). Galería con miniaturas, carpetas, ajustes y estado. Funciona sin Quickshell y sale en el launcher. | Solo al abrir |
| L3 tu Quickshell | Reusa el mismo CLI/JSON. No se integra nada a OozeWalls. | La de tu shell |

## Transiciones

Animación al cambiar de fondo, configurable (`transition`, `transition_ms`) y por llamada (`--transition`). Detalle por backend en `docs/TRANSICIONES.md`.

## Estático = cero render

Aplicar imagen mata `mpvpaper` de esa salida y guarda la ruta en
`~/.config/oozewalls/config.json`. El compositor pone el estático con su
herramienta (`hyprpaper`, `swaybg`, `awww`). Sin proceso video = 0 MB extra.

## Video eficiente

Opts fijos en `engine.rs`: `hwdec` configurable, `no-audio`, `profile=fast`,
`vd-lavc-threads=2`, `demuxer-max-bytes=16M`, sin OSD/scripts.
Cambio de video reusa el proceso vía IPC `loadfile replace`: mismo PID,
sin parpadeo, sin reiniciar daemon.
Medido aquí: 4K H264 30fps ≈ 450-510 MB RSS. 1080p anda en 150-250 MB.
Si pasas 500 MB, `status --json` marca `over_budget: true`.

## Juego / workspace

* Fullscreen: `pause` = `set_property pause true` + `SIGSTOP` (0% GPU/CPU).
  `resume` = `SIGCONT` + `pause false`. No se mata nada.
* Workspace: solo `resume`, el proceso sigue vivo en la capa `background`.

## Multi-monitor

Un socket por salida: `$XDG_RUNTIME_DIR/oozewalls/mpv_<salida>.sock`
(`*` = todas). `wallpapers{salida: ruta}` y `scaling{salida: fit|fill|stretch}`
en config. `*` tumba las salidas específicas antes de tomar todo.

## Sockets e IPC directo (mpv JSON por Unix socket)

```
echo '{"command":["loadfile","/ruta/video.mp4","replace"]}' | socat - $SOCK
echo '{"command":["set_property","pause",true]}' | socat - $SOCK
echo '{"command":["get_property","pause"]}' | socat - $SOCK
echo '{"command":["cycle","pause"]}' | socat - $SOCK
echo '{"command":["quit"]}' | socat - $SOCK
```

## CLI para Quickshell (todo configurable sin abrir nada)

```
oozewalls apply <archivo> [--output *]
oozewalls next|prev [--output *] [--all]
oozewalls stop [--output *]
oozewalls pause|resume|toggle
oozewalls status --json
oozewalls list --json [--folder <carpeta>]
oozewalls browse [--path <carpeta>] [--json]
oozewalls capabilities --json
oozewalls volume [0-100]
oozewalls mute [on|off]
oozewalls scaling [fit|fill|stretch] [--output N]
oozewalls hwdec [auto-safe|vaapi|nvdec|no]
oozewalls dirs [--json]
oozewalls dirs-add <carpeta>
oozewalls dirs-remove <carpeta>
oozewalls matugen <imagen> [--mode dark] [--scheme content]
oozewalls-gui
```

`status --json` entrega: `current, running, paused, ram_mb, over_budget,
pids, sockets[{output,pause,pid}], hwdec, compositor`.

## Biblioteca por carpetas

Cada carpeta de `dirs` es una raíz. La GUI y `browse` navegan nivel por nivel:
carpetas primero, fondos después, sin mezclar subcarpetas. `list` sin
`--folder` sigue devolviendo todo (recursivo, profundidad 4, sin ocultos) con
el campo `folder` en cada entrada. `next|prev` giran solo dentro de la carpeta
del fondo actual; `--all` usa toda la biblioteca.

```
oozewalls browse --json                       # raíces
oozewalls browse --path ~/Videos/Walls --json # un nivel
```

Forma del JSON de `browse`:

```
{ "path": "", "parent": null, "folders": [Folder], "entries": [Entry] }
Folder { name, path, videos, images, subfolders, missing }
Entry  { name, path, is_video, bytes, mtime, folder }
```

`parent`: `null` en la lista de raíces, `""` al estar en una raíz (volver a la
lista), ruta absoluta en subcarpetas. `--path` fuera de la biblioteca falla.

## Contrato IPC para oozeshell

Todo es CLI + JSON, sin daemon: `browse` para navegar, `apply <ruta> --output N`
para aplicar, `status --json` para el estado (`wallpapers` mapea salida a
ruta), `capabilities --json` para salidas. La GUI usa exactamente las mismas
funciones (`scan`, `actions`, `engine`) y escribe el mismo `config.json`, así
que ambas ven el mismo estado.

## Estáticos

Imagen: intenta `awww img` y luego `swww img` (por salida, con `--resize
crop|fit`). Si ninguno esta instalado o falla, usa la **capa propia**
(`layerbg.rs`): un proceso `oozewalls __bg` que crea una superficie
`wlr-layer-shell` con un unico buffer `wl_shm`, sin mpv. Decodifica, escala
(`fit|fill|stretch`), copia al buffer y libera la imagen; queda con unos pocos
MB de RSS. El pid vive en `$XDG_RUNTIME_DIR/oozewalls/bg_<salida>.bgpid`.
Solo si la capa propia falla cae a `mpvpaper` con `image-display-duration=inf`.
Aplicar video baja la capa estatica de esa salida y viceversa.

## Compositores

`outputs.rs` detecta `hyprland` (`hyprctl monitors -j`), `niri`
(`niri msg outputs`), resto vía `mpvpaper -d`, fallback `*`.
`capabilities --json` dice `compositor, outputs, layer, static_setter,
hwdec_options, fullscreen_probe`. Capa fija `background` para no tapar iconos.

## NVIDIA / VRAM

`hwdec` prueba `nvdec → vaapi → auto-safe`. Verifica con
`mpv --hwdec=help` y `nvidia-smi`. VRAM discreta no se mide desde `/proc`;
usa `nvidia-smi dmon` aparte. En iGPU, RAM = VRAM compartida.

## NixOS / Home Manager

Ver `package.nix` y `hm-module.nix`. Deps: `mpvpaper, mpv, ffmpeg, socat,
matugen`. Servicio opcional `oozewalls --hidden` no necesario: el estado vive
en sockets + `config.json`.

## Matugen

OozeWalls no themea. Solo `oozewalls matugen <img>` corre
`matugen image` y devuelve stdout. Tu Quickshell decide `paletteSource` y
`Theme.reload()`. Contrato: imagen aplicada → Quickshell llama a matugen →
recarga colores.

## Probar por capas

```
mpvpaper -l background -o "loop-file=inf --hwdec=auto-safe --no-audio" '*' video.mp4
oozewalls apply video.mp4 --output "*"
oozewalls status --json
oozewalls-gui
```

## App standalone + launcher

`oozewalls-gui` es la ventana propia: Biblioteca, Favoritos, Ajustes y Estado.
La biblioteca se abre por carpetas con migas de pan, búsqueda, filtro y orden.
Los videos muestran la etiqueta `Live`; el corazon de cada tarjeta alterna el
favorito y el filtro `Favoritos` muestra solo esos fondos. `favorites` se
guarda en `config.json`. Click selecciona y abre el panel de detalle; doble
click (o Enter) aplica; click derecho aplica en otra salida. Flechas mueven la
selección, Backspace sube de nivel, arrastrar una carpeta la agrega. Miniaturas
16:9 cacheadas en `~/.cache/oozewalls/thumbs` (imágenes y videos vía `ffmpeg`),
generadas en hilos. Aplicar, pausa, estado y diálogos corren fuera del hilo de
UI. La barra inferior tiene prev/pausa/next/stop, volumen y RAM y se adapta al
ancho. El idioma de la interfaz (`language`: `es` o `en`) se elige en Ajustes.
Cada cambio de ajustes se guarda al instante.
`./install.sh` compila release, instala en `~/.local/bin`, genera el wrapper
con `LD_LIBRARY_PATH` de NixOS y registra `oozewalls-gui.desktop` para
buscarla en el launcher sin depender de Quickshell.

## Presupuesto

Meta ≤500 MB. 4K H264 la roza; si la rompes, baja a copias 1080p30
(`ffmpeg -vf scale=-2:1080,fps=30 -c:v libx264 -crf 23 -an`) o usa
`hwdec=nvdec/vaapi` real.

## Paleta (matugen)

`oozewalls palette` replica `runMatugen` de OozeShell: corre `matugen image`
con `--source-color-index`, `-t scheme-<esquema>` y `-m dark|light`, aplica las
plantillas y escribe el JSON `--json hex` (atomico) en `colors_file`
(`~/.cache/oozeshell/colors.json` por defecto), que `Theme.qml` vigila.
Esquemas: vibrant, tonal-spot, neutral, fruit-salad, rainbow, fidelity,
content, monochrome. `--probe --json` lista los colores fuente 1-6 para las
muestras. `apply` genera la paleta solo si `palette_auto` esta activo (y no se
paso `--no-palette`), y escribe `~/.cache/awww/last` para lockscreen/launcher.

## Autoinicio

`oozewalls restore [--force] [--only live|static]` reaplica `wallpapers` de
`config.json` (reintenta mientras el compositor levanta; no hace nada si ya hay
un fondo vivo). Opciones: `exec-once = oozewalls restore` en Hyprland (o su
equivalente en tu config Lua), el servicio de Home Manager
`programs.oozewalls.autostart = true`, o simplemente OozeShell: con el motor
OozeWalls elegido restaura solo al iniciar.

## Config (`oozewalls set <clave> <valor>`)

`static_backend` (auto|awww|builtin|mpvpaper), `scheme`, `source_index`,
`palette_mode`, `palette_auto`, `colors_file`, `hwdec`, `layer`, `output`,
`mute`, `volume`, `transition`, `transition_ms`, `favorites`, `language`.
`oozewalls config` imprime todo el JSON.

## Apariencia de la GUI

Ajustes → Apariencia permite elegir paleta y tamaño de fuente. Se guardan en
`config.json` como `ui_palette` (`violet`, `ocean`, `emerald`, `rose`, `amber`,
`graphite`) y `ui_font` (`small` 90%, `normal` 100%, `large` 115%, `xlarge`
130%). Los colores ya no son constantes: `pal()` devuelve la paleta activa y
`fs()`/`pf()` escalan cualquier tamaño de texto. Al cambiar una opción se
reaplica `theme()` al instante. Las paletas son oscuras; los colores de estado
(`OK`, `WARN`, `BAD`) no cambian.

## Filtros de la biblioteca

Los chips (Todos, Live, Imágenes, Favoritos) y los controles Ordenar, Tamaño y
Aplicar en se acomodan en filas según el ancho disponible, igual que la
rejilla de fondos. Cada elemento tiene un ancho estimado y se llena la fila
hasta que no cabe el siguiente. Ya no dependen de que el panel de detalle esté
abierto.

## Cierres inesperados de la GUI

El watchdog `OOZEWALLS_GUI_WATCHDOG` ya no aborta el proceso. Con la ventana en
otro workspace o tapada, el compositor deja de enviar frame callbacks y
`eglSwapBuffers` puede bloquear el hilo de UI sin que la app esté colgada; el
watchdog anterior lo interpretaba como un cuelgue y hacía `abort()` a los 4 s.
Ahora solo registra un reporte tras 30 s sin latido.

`~/.cache/oozewalls/gui-crash.log` registra cómo termina cada sesión:

| Línea | Significado |
|---|---|
| `panic: ...` | Pánico en el hilo principal |
| `signal: SIGTERM` / `SIGHUP` / `SIGINT` | Otro proceso o la sesión cerró la GUI |
| `exit: error ...` | eframe terminó con error |
| `exit: ok` | Cierre normal |
| `ANR heartbeat=...` | Más de 30 s sin latido (solo con el watchdog activo) |

Si tras cerrarse no aparece ninguna línea, el proceso murió por `SIGKILL`
(por ejemplo, OOM killer): revisar `journalctl -k | grep -i oom`.
