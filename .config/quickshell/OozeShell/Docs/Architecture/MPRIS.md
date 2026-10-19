# MPRIS — reproductor multimedia (backend D-Bus + popup + ondas)

- Qué es: popup de control multimedia y el único punto que lee/controla reproductores MPRIS. Ya no usa `playerctl`: lee directo del servicio MPRIS nativo de Quickshell por D-Bus y eventos.
- Archivos:
  - `Services/Mpris/MprisBackend.qml` → `pragma Singleton` (registrado en `qmldir`); expone `players`, `currentTitle/Artist/Art/Status/Position/Length`, `selectPlayer(i)`, `runCtl(args)` (`play-pause | next | previous | position <secs>`), `currentVolume`, `volumeMuted`, `volumeIcon`, `setVolume(v)`, `commitVolume()`, `toggleVolumeMute()` (volumen del sistema vía `AudioBackend`)
  - `Services/Mpris/Mpris.qml` → popup (`oozeshell-mpris`), delega todo al backend
  - `Services/Mpris/MprisWaves.qml` → visualización de ondas (puro `QtQuick.Shapes` + `COMMON`)
  - `Services/Mpris/MprisVolume.qml` → slider de volumen (horizontal en el popup, `vertical: true` en el dashboard)
  - `Services/Mpris/qmldir` → `singleton MprisBackend`, `Mpris`, `MprisWaves`, `MprisVolume`
- IPC (Core/Ipc/MprisIpc.qml, target `mpris`):

  | Función | Efecto |
  |---|---|
  | `toggle` | en modo píldora abre la sección `mpris` del dashboard; si no, popup propio |

  ```sh
  quickshell ipc -p .../shell.qml call -- mpris toggle
  ```
- Estado y datos: `MprisBackend` en memoria (`players`, `manualIndex`, `wanters`). Sin JSON. El polling de posición (Timer 500 ms) solo corre si hay interesados (`wanters`: el popup se registra con `setWanted("popup", …)`) y el estado es `Playing`; en modo rendimiento (`Theme.performanceMode`) `PillMedia` no carga la carátula.
- Dependencias: `Quickshell.Services.Mpris`, `COMMON`, `Services/Lang`, `Services/Audio`. Consumido por `Modules/Pill/PillMedia.qml`, `Modules/Dashboard/DashboardMpris.qml` y `Modules/Lock/LockMedia.qml` (que se registra con `setWanted("lock", …)` mientras la sesión está bloqueada).
- Notas: los controles (play/pausa/siguiente/anterior/seek) no son IPC: se llaman desde QML vía `MprisBackend.runCtl([...])`. Posición y duración en microsegundos.
