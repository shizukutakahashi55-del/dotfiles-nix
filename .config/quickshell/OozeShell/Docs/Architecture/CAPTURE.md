# CAPTURE — capturas y grabación de pantalla

- Qué es
  - Capturas con `grim` y grabación de video con `wf-recorder`, con dos modos: zona (selector con la pantalla congelada) y pantalla completa (el monitor enfocado).
  - Mientras se graba aparece un indicador (punto rojo parpadeante + tiempo) en la barra y en la píldora. Clic izquierdo pausa o reanuda; clic derecho abre el menú.
- Archivos
  - `Services/Screenshot/RecorderBackend.qml` → singleton con la máquina de estados (`idle`, `preparing`, `countdown`, `recording`, `paused`, `finishing`), el reloj y el menú (`menuEntry`).
  - `Services/Screenshot/CaptureConfig.qml` → singleton con los ajustes (guardados en `~/.config/oozeshell/config.toml`, clave `capture`) y los comandos de captura.
  - `Services/Screenshot/ScreenshotBackend.qml` → selector de zona y capturas; `ScreenshotFreeze.qml` → ventana del selector (sirve a capturas y grabación).
  - `Tools/ooze-capture.sh` → `shot`, `recpath`, `recseg`, `recjoin`, `open`.
  - `Core/Ipc/RecordIpc.qml` → target `record`.
  - `Modules/Privacy/Privacy.qml` → icono de grabación (`RecordIcon`), compartido por `Modules/Bar/modules/PrivacyModule.qml` y `Modules/Pill/PillTray.qml`.
  - `Modules/Tray/TrayMenuList.qml` → también pinta menús propios: una entrada con `custom: true`, `title`, `glyph` e `items`.
  - `Settings/pages/CapturePage.qml` y `Settings/FolderField.qml` → categoría «Capturas y grabación».
- Indicador
  - Vive dentro del módulo `privacy`: si ese módulo no está en la barra, la barra no muestra el icono. En modo píldora sale en la píldora derecha y el menú se despliega como el de la bandeja.
  - Menú (clic derecho): Pausar/Reanudar, Detener y guardar, Descartar, Nueva grabación de zona, Nueva grabación de pantalla completa, Abrir carpeta de grabaciones. «Nueva» guarda la actual y empieza la siguiente.
- Pausa
  - `wf-recorder` no pausa: cada pausa cierra un segmento y reanudar abre otro. Al detener, `ffmpeg -f concat -c copy` los une en un solo archivo (sin recodificar). Sin `ffmpeg`, los segmentos se guardan como `nombre_part1`, `nombre_part2`…
  - Los segmentos viven en `~/.cache/oozeshell/rec/` hasta unirse.
- Dónde empieza a grabar
  - Dashboard → Acceso rápido: mosaicos «Grabar zona» y «Grabar pantalla» (con la grabación activa detienen y guardan).
  - Launcher (`>`): «Grabar: zona», «Grabar: pantalla completa», «Detener grabación».
  - IPC.
- IPC (`qs ipc call record …`)
  | función | efecto |
  |---|---|
  | `toggleArea` / `toggleScreen` | empieza la grabación o, si ya hay una, la detiene y guarda |
  | `startArea` / `startScreen` | empieza (no hace nada si ya hay una) |
  | `stop` | detiene y guarda |
  | `pause` / `resume` / `togglePause` | pausa y reanuda |
  | `cancel` | descarta la grabación |
  | `status` | devuelve fase y tiempo, por ejemplo `recording 01:23` |
- Ajustes (Ajustes avanzados → Capturas y grabación)
  - Carpetas de capturas y de grabaciones (vacío = `Imágenes/Screenshots` y `Vídeos/Recordings`), nombres con formato de fecha `strftime`.
  - Capturas: PNG o JPEG (con calidad), cursor, copiar también al portapapeles.
  - Grabación: MP4, MKV o WebM; 24/30/60 fps; calidad baja/media/alta; audio ninguno, del sistema o micrófono; codificador (CPU, NVENC de NVIDIA o VAAPI de AMD/Intel); cuenta atrás.
  - Avisos al terminar y comprobación de las herramientas instaladas.
- Audio
  - El dispositivo se resuelve con `pactl` (o `wpctl` si falta): «sistema» usa el monitor de la salida por defecto, «micrófono» la entrada por defecto. Cada segmento deja en `~/.cache/oozeshell/rec.log` el comando de `wf-recorder` y su salida de error.
- Dependencias: `grim`, `wl-clipboard`, `wf-recorder`, `ffmpeg`, `libnotify`, `pulseaudio` (solo el binario `pactl`, para elegir el audio), `xdg-utils` y `xdg-user-dirs`.
