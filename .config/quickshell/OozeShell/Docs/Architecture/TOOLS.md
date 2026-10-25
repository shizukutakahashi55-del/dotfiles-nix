# TOOLS — scripts de desarrollo y ayuda

- Qué es: utilidades bash/python que no viven dentro del shell. Ninguna corre dentro de Quickshell salvo
  llamadas puntuales (`Services/OozeAudio/backend/audio.sh restore`,
  `Services/PackageSearch/installed.sh`).
- Archivos:
  - `Tools/check.sh` — chequeo rápido: páginas de `SettingsRegistry`, claves de traducción en `es`/`en` y
    `qmllint`. Uso: `cd OozeShell && bash Tools/check.sh`.
  - `Tools/ooze-run.sh` — compila, arranca, lista backends, diagnostica fuentes y hace benchmark
    (`build | run | backends | fonts | bench | stop`); sin argumentos imprime su ayuda. Logs en
    `~/.cache/oozeshell/bench/run-*.log`. Variables: `QS_BIN`, `OOZE_PREFIX`, `OOZE_LOGDIR`.
  - `Tools/oozeshell` — lanzador corto del IPC: `oozeshell apps open browser`, `oozeshell toggle launcher`,
    `oozeshell list` (ver DEFAULTAPPS.md). `self=<repo>` es la copia que se instala en `~/.local/bin/oozeshell`.
  - `Tools/build-native.sh` — compila e instala el módulo C++ `OozeShell.Native` (ver CORE.md).
  - `Tools/live-optimize.sh` — copia liviana de un vídeo para wallpaper animado (lo usa
    `Services/Walls/Walls.qml`).
  - `Tools/online-wallpapers.sh` — busca wallpapers en línea para el modo Online de
    `Services/Walls/Walls.qml`.
  - `Tools/online-live.sh` — lista wallpapers live de Moewalls/WallpaperWaifu (miniaturas, vídeo, vista previa).
  - `Tools/online-clip.sh` — genera los GIF de vista previa de Online Live.
  - `Tools/online-resolve.sh` — elige el vídeo de mayor calidad de un post.
  - `Tools/online-download.sh` — descarga el vídeo elegido (aria2c o curl con reanudación).
  - `Tools/ooze-capture.sh` — capturas y grabación (`shot | recpath | recseg | recjoin | open`); lo usan
    `Services/Screenshot/CaptureConfig.qml` y `RecorderBackend.qml` con los ajustes por variables `CAP_*` (ver CAPTURE.md).
  - `Tools/palette-apply.py` — aplica la paleta de colores al resto del sistema (lo lanza `COMMON/Theme.qml`).
  - `Tools/fonts/` — `99-oozeshell-pixel.conf` (fontconfig de la fuente pixel), `fonts.nix.example` y
    `fonts-coozey.nix.example` (ejemplos de configuración de fuentes en home-manager).
- Scripts que no están en `Tools/`:
  - `Modules/Keybinds/keybinds_tool.py` — generador de keybinds (preserva los números de línea al generar).
  - `Services/OozeAudio/backend/audio.sh` — persistencia y ruteo de audio PipeWire (`restore`, `app-rules`,
    `stream-move`, …). Ver AUDIO.md.
  - `Services/PackageSearch/installed.sh` — lista de paquetes instalados (solo Arch). Ver LAUNCHER.md.
- Notas: el uso detallado de cada script vive solo en su cabecera (nombre + 1 línea); el detalle completo
  quedó fuera de los archivos a propósito.
