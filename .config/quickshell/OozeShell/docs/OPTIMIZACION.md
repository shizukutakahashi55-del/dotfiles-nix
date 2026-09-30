# OozeShell-opti — documentación del avance de optimización

> **Estado.** Estos cambios se escribieron y probaron **sin poder ejecutar
> Quickshell** (ver la checklist de §6). Lo que sí se probó de verdad: el script
> `tools/live-optimize.sh` (con videos sintéticos), la construcción del comando de
> lanzamiento de mpvpaper (con un mpvpaper falso) y el balance de llaves de los
> `.qml` editados.

## 1. Punto de partida (qué se midió leyendo el código)

| Módulo | Problema |
|---|---|
| `MPRIS/MprisBackend.qml` | 1 proceso `playerctl` **cada 500 ms** (y otro cada 3 s) mientras el popup/dashboard están abiertos. Cada uno = fork + exec + D-Bus. |
| `BAR/LEFT/LeftModules.qml` | Un `playerctl -F` **permanente** solo para el título de la barra. |
| `WALLS/Walls.qml` (live) | mpv decodifica el video a su resolución original (un 4K@60 ocupa ~8× la memoria de un 1080p@30). Al "pausar" por fullscreen el proceso seguía vivo con RAM y texturas reservadas. Fuga conocida de mpvpaper con `loop-file=inf`. |

## 2. Decisión: ¿backends en C++ / Python?

**Por ahora no.** La memoria de vídeo (VRAM) de OozeShell sale de tres sitios y
ninguno se arregla reescribiendo lógica en otro lenguaje:

1. **mpvpaper** — decodificador + texturas del video (arreglado en §3.2).
2. **Texturas de Qt Quick** — `layer.enabled`, `Image` sin `sourceSize`, sombras.
   Se arreglan en QML (auditoría pendiente, §5).
3. **Procesos auxiliares** (`playerctl`, `cava`, `hyprctl`…) — eso es CPU/RAM, no
   VRAM; el de MPRIS se eliminó usando el módulo **nativo** de Quickshell (§3.1),
   que ya es C++ y funciona por eventos.

`native/AnimationController` (prototipo C++ de animaciones) sigue sin importarse
desde la shell: reemplaza una función de 3 líneas de `Theme.animDuration()`, así
que no aporta ahorro medible y sí añade compilar un plugin por cada
distro/Nix. **Recomendación:** dejarlo en pausa hasta tener una animación que
realmente necesite lógica nativa (p. ej. física por fotograma con muchos objetos).

Un backend externo (Python/C++) solo compensaría si hiciera algo que Quickshell
no puede: por ejemplo un demonio que decodifique el wallpaper una sola vez y
lo comparta como textura. Eso sí reduciría VRAM, pero es un proyecto aparte
(candidato de fase 3, §5).

## 3. Cambios hechos

### 3.1 MPRIS nativo (sin `playerctl`)

- `MPRIS/MprisBackend.qml` reescrito sobre `Quickshell.Services.Mpris`
  (importado con alias `QsMpris` para no chocar con el tipo local `Mpris`).
  El original queda como `MprisBackend.qml.bak`.
- **API pública idéntica** → `Mpris.qml` y `DashboardMpris.qml` no se tocaron.
- Título, artista, carátula y estado llegan por señales D-Bus (0 procesos). Solo
  la posición usa un `Timer` de 500 ms, activo **únicamente** con alguien
  mirando (`setWanted`) y algo sonando.
- `BAR/LEFT/LeftModules.qml`: se eliminó el `playerctl -F` y su reintento;
  ahora `mprisStatus/Artist/Title` son bindings al backend, y los clics/rueda
  llaman a `MprisBackend.runCtl`.
- **Cambio de comportamiento:** si no eliges un player a mano se sigue al que
  está *sonando* (antes, el primero de la lista). Elegir uno con el chip lo fija
  hasta que cambie la lista de players.
- `playerctl` ya **no es dependencia** de la shell.

### 3.2 Live wallpapers (`WALLS/Walls.qml`; original: `Walls.qml.pre-opti`)

| Mejora | Qué hace | Ajuste |
|---|---|---|
| Copia liviana | `tools/live-optimize.sh` crea 1080p/30 fps/H.264 sin audio en `~/.cache/oozeshell/live/opt/`. Se genera en segundo plano con `nice`+`ionice` tras elegir un video, y mpvpaper la usa (al instante con `liveOptSwap`, o en el siguiente arranque). Si el video ya es liviano, no hace nada. | `liveOptimize`, `liveOptSwap`, `liveOptMaxHeight`, `liveOptMaxFps` |
| Parar en vez de pausar | Con fullscreen encima o perfil `power-saver` se **mata** mpvpaper (RAM y VRAM a 0) y se relanza al volver. | `liveStopWhenHidden` (false = pausa como antes) |
| Vigilante de RAM | Cada 60 s suma el RSS de mpvpaper; si supera el tope lo relanza (contiene la fuga del loop). Registra en el log de Quickshell: `[live] RAM mpvpaper: N MB`. | `liveRamLimitMB` (900; 0 = off) |
| Opciones de mpv | `profile=fast`, `vd-lavc-threads=2`, `load-scripts=no`, `ytdl=no`, `osd-level=0` (se suman a `cache=no` y límites de demuxer que ya tenías). | `mpvOptions` |

Uso manual del optimizador:

```sh
bash tools/live-optimize.sh ~/Pictures/Wallpapers/Live/video.mp4 1080 30
# LIVE_OPT_CRF=28 para más chico; salida: la ruta de la copia
```

Pruebas hechas del script: 4K60 → 1080p30 (27 MB → 0,3 MB en un clip de prueba),
1080p60 → solo baja los fps, 720p30 H.264 → sale con código 2 sin generar nada,
segunda corrida reutiliza la copia, rutas con espacios.

## 4. Cómo medir el antes/después

```sh
# RAM de mpvpaper (MB) — el vigilante también lo imprime cada minuto
pgrep -f '[m]pvpaper' | xargs -r ps -o rss= -p | awk '{s+=$1} END{print int(s/1024)" MB"}'
# VRAM
nvidia-smi --query-compute-apps=pid,used_memory --format=csv      # NVIDIA
cat /sys/class/drm/card*/device/mem_info_vram_used                # AMD (bytes)
# ¿Sigue habiendo playerctl?  (debe salir vacío)
pgrep -a playerctl
```

## 5. Siguientes pasos (no hechos)

1. ~~Auditoría de texturas~~ → hecha en la Fase 2 (§7).
2. **Ajustes en la UI**: exponer `liveStopWhenHidden`, `liveRamLimitMB` y
   `liveOptimize` en Ajustes → General → Launcher (hoy se cambian en `Walls.qml`).
3. **Animaciones**: mantener `native/AnimationController` en pausa (ver §2).
4. **Fase 3 (opcional)**: demonio único de wallpaper que comparta la textura.

## 6. Checklist para la primera prueba

- [ ] La shell arranca sin errores de QML (mirar `qs log`; si falla, lo más probable
      es el alias `QsMpris` o `MprisPlaybackState` en `MprisBackend.qml`).
- [ ] Reproducir algo: la barra muestra título/estado; abrir el popup MPRIS y ver
      que la barra de progreso avanza (si se queda en 0, revisar `syncPosition()`).
- [ ] Seek con clic en la barra de progreso; siguiente/anterior con rueda y clic derecho.
- [ ] Dos players a la vez: el chip cambia de player y el automático sigue al que suena.
- [ ] Elegir un video live: aparece `[live] optimizar … -> código 0` y luego se
      relanza una vez; `ls ~/.cache/oozeshell/live/opt/`.
- [ ] Abrir una ventana en fullscreen sobre la pantalla del wallpaper: `pgrep -f '[m]pvpaper'`
      debe salir vacío; al salir del fullscreen el video vuelve.
- [ ] Dejar 1–2 horas y comparar la RAM con el punto de partida.


---

## 7. Fase 2 — auditoría de texturas y lag de Ajustes avanzados

### 7.1 Resultado de la auditoría de texturas

| Elemento | Hallazgo | Acción |
|---|---|---|
| `Image` de carátula en `MPRIS/Mpris.qml` (2) | Sin `sourceSize`: Qt decodifica la carátula a su tamaño original (una de 1200×1200 ≈ 5,5 MB) para un fondo al 45 % y una miniatura de 92 px. | **Corregido**: 720×720 el fondo, 256×256 la miniatura (original: `Mpris.qml.pre-opti`). |
| `IconImage` (Dock, Taskbar, Tray, menús…) | Marcados por la búsqueda, pero es un tipo de Quickshell que ya dimensiona su textura al ícono. | Sin cambios (falso positivo). |
| `layer.enabled` en `FusedPanel` (4), `Avatar` (2), `DashboardMpris` (5) | Son máscaras/recortes necesarios. Cerrado el panel su tamaño es 0 o la ventana es invisible, así que no retienen memoria útil. | Sin cambios: condicionarlos añadiría riesgo de parpadeo al abrir y ahorro casi nulo. |
| `LockScreen` (blur) | Ya usa `sourceSize` = tamaño de pantalla y solo existe bloqueado. | Sin cambios. |
| **`FusedWindow` ×21** | **El hallazgo grande.** Cada popup es una superficie layer-shell a pantalla completa que queda montada siempre (búferes ARGB del tamaño de la pantalla + su propia escena de Qt Quick). Es más VRAM que cualquier `layer.enabled`. | **Opt-in**: `OOZESHELL_LAZY_WINDOWS=1 quickshell` monta cada ventana solo mientras se usa (+0,9 s de margen para el cierre). Apagado por defecto (ver riesgos). |

Riesgos del montaje perezoso (por eso es opt-in y **sin probar**): el comentario de
`FusedWindow.qml` explica que se dejó montada a propósito porque al mapear la
ventana Hyprland le aplicaba su animación de capa ("spawn encima", corrimiento de
1-2 px). Si al probarlo ves eso, hay que desactivar la animación de layers para
el namespace `oozeshell-*` en tu configuración de Hyprland. Mide antes/después
(§4): si el ahorro no compensa, déjalo apagado.

### 7.2 Lag de Ajustes avanzados: causa y arreglo (en QML, no hace falta C++)

Se leyó `SETTINGS/AdvancedSettings.qml` (4134 líneas). Causas encontradas:

1. **Las 6 categorías inline se creaban todas de golpe.** Solo se ocultaban con
   `visible:`; los ~3000 líneas de QML (cientos de ítems, 44 `Behavior`, 24
   `Repeater`) existían siempre y sus bindings se reevaluaban con cada cambio de
   tema o de wallpaper aunque no se vieran. Solo las páginas migradas
   (`pages/`) usaban `Loader`.
2. **La búsqueda hacía todo el trabajo en cada tecla**: normalizaba (NFD +
   regex) 5 cadenas por cada entrada del índice y reconstruía la lista al instante.

**Arreglos hechos** (original: `AdvancedSettings.qml.pre-opti`):

- `interface`, `audio` y `general` (las 3 mayores sin dependencias externas: 968,
  293 y 468 líneas) ahora van en un `Loader`: solo existe la categoría elegida,
  y se destruye al cerrar la ventana. Mismo patrón que `pageLoader`.
- Búsqueda: el texto normalizado se calcula **una vez** por cambio de índice o de
  idioma (`searchHay`) y cada tecla solo hace `indexOf`; además hay un debounce
  de 110 ms (vaciar el campo sigue siendo inmediato).

**Pendiente**: `appearance`, `profile` e `hypr` siguen inline porque se
referencian ids internos desde fuera (`profileBrowser`, `hmMapCard`, y `chip` /
`chipArea` en Apariencia). Requieren moverlos a `pages/` (guía §8), no un
simple `Loader`.

**Efecto secundario a vigilar**: al cambiar de categoría, lo que estaba escrito y
no guardado dentro de `interface`/`audio`/`general` (campos de texto, secciones
plegadas) se pierde, porque ahora se destruye la categoría.

### 7.3 ¿Pasar Ajustes avanzados a C++?

**No.** El lag no viene de que QML/JS sea lento sino de instanciar de más (§7.2).
Un núcleo en C++ solo movería la lógica: los ~3000 ítems visuales seguirían
siendo QML y seguirían creándose. Además exigiría compilar un plugin por
distro/Nix (ya se descartó igual para `AnimationController`). Lo que sí
compensaría, si tras los `Loader` aún notas lag, es un `QAbstractListModel`
en C++ para el índice de búsqueda — pero con 100-300 entradas ya cacheadas no
debería hacer falta. **Mide primero** (§7.4).

### 7.4 Cómo medir el lag

```sh
# Ver cuánto tarda en abrirse: tiempo entre pulsar el atajo y ver la ventana.
# Perfilado real de QML (necesita Qt con el perfilador):
QSG_RENDER_TIMING=1 quickshell 2>&1 | grep -i "frame\|render"
# Memoria de la shell (MB):
pgrep -x quickshell | xargs -r ps -o rss= -p | awk '{print int($1/1024)" MB"}'
```

### 7.5 Checklist Fase 2

- [ ] Abrir Ajustes avanzados: aparece la categoría elegida; cambiar entre General,
      Interfaz y Audio sin errores en `qs log` (si una sale vacía, mirar
      `catLoader_*` en `AdvancedSettings.qml`).
- [ ] Buscar una opción de esas 3 categorías, hacer clic en el resultado: debe
      abrir la categoría, hacer scroll y resaltar la tarjeta (`scrollToAnchor`).
- [ ] Escribir rápido en el buscador: la lista se actualiza tras una pausa breve,
      Esc vacía el campo al instante.
- [ ] Reproducir algo con carátula grande: el popup MPRIS se ve igual de nítido.
- [ ] (Opcional) `OOZESHELL_LAZY_WINDOWS=1`: abrir/cerrar varios popups, comprobar
      foco de teclado (Esc, teclado en Launcher/Overview) y ausencia de "spawn".


---

## 8. Fase 3 — popups destruidos al cerrarse (`LazyPopup`)

**Por qué la Fase 2 no bajó la VRAM:** `FusedWindow` con `OOZESHELL_LAZY_WINDOWS` apagado
(valor por defecto) es idéntico al original, y aun encendido solo pone
`PanelWindow.visible = false`: la escena de Qt Quick sigue viva. Para liberar los búferes
hay que **destruir** el objeto. Además `native/AnimationController` no está importado por
la shell, así que no influye en la VRAM.

**Cambio:** `COMMON/LazyPopup.qml` (un `LazyLoader` con `wanted`/`open`/`grace`). En
`shell.qml` se envolvieron 10 popups que no guardan estado propio: `LanguagePicker`,
`AdvancedSettings`, `MonitorEditor`, `LauncherSettings`, `TerminalSettings`, `Appearance`,
`MonitorSelect`, `Keybinds`, `BluetoothMenu`, `NetworkMenu` (y, en la 4.ª tanda, `Launcher` y
`NixSearch`, ver §9). Existen solo mientras están
abiertos (+1,2 s de gracia para la animación de cierre). No se tocaron: `Walls` (proceso
del wallpaper y `Theme.wallpaperChanging`), `Notify` (toasts), `Launcher`, `NixSearch`,
`PowerMenu`, `LockScreen`, OSDs.

**Cómo medir:** reiniciar la shell y comparar `nvidia-smi` en reposo con `opti2`.

**Riesgo conocido:** al crearse la ventana, Hyprland puede aplicarle su animación de capa
(el "spawn encima" que comenta `FusedWindow.qml`). Si aparece, desactivar animaciones de
layers para `oozeshell-.*` en la config de Hyprland.


## 9. Fase 4 — Launcher y NixSearch bajo demanda

Medido tras la Fase 3: **391 MB en reposo, 405 MB con el Dashboard abierto** (antes 639 / 710).

- `Launcher` y `NixSearch` ahora van dentro de `LazyPopup` (`openDelay: 50` para que se sientan
  inmediatos).
- **Cambio necesario:** los IPC escribían `launcher.startMode` y `nixSearch.startQuery` antes de
  abrir; con el popup destruido esos ids no existen. Ahora son propiedades de `root`
  (`launcherStartMode`, `nixStartQuery`) y el popup las lee al crearse.
- Ambos ya reiniciaban todo su estado en `onOpenChanged`, y no guardan historial en memoria, así
  que destruirlos no pierde nada. Coste: cada apertura reconstruye la lista de apps (ordenar
  `DesktopEntries`), unos pocos ms.
- **Comportamiento a vigilar:** si escribes apenas pulsas el atajo, las primeras teclas (~50–150 ms)
  pueden ir a la ventana anterior mientras se crea el popup.

### Checklist
- [ ] `launcher toggle`, `launcher open windows|run|files` abren en el modo correcto.
- [ ] `nixsearch open firefox` abre ya buscando "firefox".
- [ ] Abrir/cerrar 10 veces seguidas y comprobar que el `nvidia-smi` no crece (sin fugas).
- [ ] Ajustes avanzados abierto + Launcher encima siguen conviviendo.


## 10. Ajuste visual CoOzey — workspaces y bordes pixel (no afecta a la VRAM)

- `COMMON/WorkspaceChip.qml` (nuevo): botón de workspace. En CoOzey **todos** los workspaces
  son cajas pixel (inactivo: caja hundida con número atenuado; activo: color primario, contorno
  de tinta y negrita). En OozeSoft queda igual que antes. Lo usan `CenterModules`,
  `PillWorkspaces` (y por tanto `PillWorkspacesSide`).
- En CoOzey los workspaces ya no se escalan al pasar el mouse (el escalado fraccionario
  emborrona texto y bordes pixel) y hay 3 px entre cajas.
- Fondos redondeados → `SkinRect` (esquinas escalonadas) en CoOzey: isla central y derecha
  (modo Islas), botón de notificaciones, reloj, campana y batería de la píldora, y la píldora
  lateral de workspaces.
