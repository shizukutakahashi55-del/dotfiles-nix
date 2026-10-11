# AUDIO — Panel de volumen PipeWire + OozeAudio (salidas virtuales)

- Qué es: backend único (`AudioBackend`, singleton PipeWire/wpctl) para volumen salida/entrada, mixer por app y ruteo por salida; más OozeAudio, app aparte para crear salidas virtuales `ooze_*` (pw-loopback) y cablearlas. Este doc cubre ambos.
- Archivos:
  - `AUDIO/AudioBackend.qml` → `pragma Singleton`: sink/source default (Pipewire + fallback `wpctl`), `sinks`/`sources` (parseo `wpctl status`), `streamNodes`/`outputTargets`, reglas por app (`appRules`), `routeStream`/`forgetRule`, OSD state, `restoreOutputs`.
  - `AUDIO/AudioMenu.qml` → popup 3 pestañas (Salida/Entrada/Mixer): sliders, lista de dispositivos, volumen por app y `StreamOutputPicker` por fila.
  - `AUDIO/AudioOSD.qml` → píldora flotante abajo (Overlay) que muestra `osdKind`/`osdValue`/`osdMuted` 1,6 s.
  - `AUDIO/AppsRouting.qml` → sección "Aplicaciones" reutilizable (apps sonando + reglas guardadas de apps inactivas).
  - `AUDIO/StreamOutputPicker.qml` → desplegable de salida por stream (usa `PwNodeLinkTracker` + `ruleSink`).
  - `OozeAudio/shell.qml` → ventana flotante propia (900×700): `Header` + `ConnectionsPanel` + `EditorPanel` + `CreateDialog` + toast de error.
  - `OozeAudio/data/AudioService.qml` → `pragma Singleton`: invoca `audio.sh` (`outputs/sinks/sources/streams/links/create/delete/connect/disconnect/volume-set/mute-set`), estado local optimista.
  - `OozeAudio/backend/audio.sh` → backend bash (~1334 líneas): requiere `pw-cli pw-dump pw-link pw-loopback jq pgrep systemd-run systemctl wpctl flock`; subcomandos `status sinks sources streams outputs dump create delete links connect disconnect volume-set mute-set restore app-rules app-forget stream-move stream-route stream-unroute state`.
  - `OozeAudio/components/` → `Header`, `ConnectionsPanel`, `ConnectionCard`, `EditorPanel`, `CreateDialog` (UI de la ventana).
- IPC:

  | target | función | efecto |
  |---|---|---|
  | `audio` | `toggle` | abre popup (o dashboard `audio` en `pillMode`) |
  | `audio` | `raise` / `lower` / `mute` | ±5 % volumen / mute con OSD |
  | `audio` | `micToggle` / `micRaise` / `micLower` | mute / ±5 % micrófono con OSD |

  ```bash
  quickshell ipc -p .../shell.qml call -- audio toggle
  quickshell ipc -p .../shell.qml call -- audio raise
  quickshell ipc -p .../shell.qml call -- audio mute
  quickshell ipc -p .../shell.qml call -- audio micToggle
  ```
- Estado y datos: `AudioBackend` es singleton sin JSON propio; reglas de apps y salidas las guarda `audio.sh` (ver `restore`, `app-rules`, `state` en el script). OozeAudio no usa IPC: es proceso Quickshell aparte (`FloatingWindow`).
- Dependencias: `Quickshell.Services.Pipewire` (event-driven; `wpctl` solo como fallback/acciones), `../COMMON` (Theme, SkinRect, AppIcon), `../LANG`, `../BRIGHTNESS` (slider de brillo en pestaña Salida). OozeAudio solo depende de su `audio.sh` + `pw-*`.
- Notas: `watchers`/`menuWatch`: listas de dispositivos y streams solo se escanean con el panel abierto (timers 1 s/1,5 s). Al subir volumen se desmutea solo. Los nodos `ooze_*` se etiquetan `Ooze_…` y se excluyen del ruteo automático. No confundir `AUDIO/` (shell integrado) con `OozeAudio/` (app externa de cableado virtual).
