# TOOLS — scripts de desarrollo y ayuda

- Qué es: utilidades bash/python fuera del shell en vivo. Ninguna corre dentro de Quickshell salvo llamadas puntuales (`audio.sh restore`, `installed.sh`).
- Archivos:
  - `tools/check.sh` — chequeo rápido: páginas de `SettingsRegistry`, claves de traducción en los 4 idiomas, `qmllint`. Uso: `cd OozeShell && bash tools/check.sh`.
  - `tools/ooze-run.sh` — compila, arranca, lista backends, diagnostica fuentes y hace benchmark (`build|run|backends|fonts|bench|stop`).
  - `tools/build-native.sh` — compila el módulo C++ `OozeShell.Native`.
  - `tools/live-optimize.sh` — copia liviana de un video para wallpaper animado (la usa WALLS).
  - `tools/online-wallpapers.sh` — busca wallpapers en línea para el modo Online de WALLS.
  - `tools/palette-apply.py` — aplica paleta de colores.
  - `Keybinds/keybinds_tool.py` — generador de keybinds (preserva números de línea al generar).
  - `OozeAudio/backend/audio.sh` — persistencia y ruteo de audio PipeWire (`restore`, `app-rules`, `stream-move`, …). Ver AUDIO.md.
  - `PackageSearch/installed.sh` — lista de paquetes instalados (solo Arch). Ver LAUNCHER.md.
- Notas: tras la limpieza, el uso detallado de cada script vive solo en su cabecera (nombre + 1 línea); el detalle completo quedó fuera de los archivos a propósito.
