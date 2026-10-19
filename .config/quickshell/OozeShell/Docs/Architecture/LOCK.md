# LOCK — OozeLock, la pantalla de bloqueo

OozeLock bloquea la sesión con `WlSessionLock` y autentica contra PAM. Además del campo de contraseña muestra reloj, perfil, clima, reproductor MPRIS y estado del equipo. Todo lo opcional se activa y ajusta desde **Ajustes → Escritorio → OozeLock**.

## Mapa de archivos

| Archivo | Rol |
|---|---|
| `Modules/Lock/LockScreen.qml` | Raíz. Sesión de bloqueo, PAM, teclado y composición visual de todos los bloques |
| `Modules/Lock/LockField.qml` | Campo de contraseña (puntos, estado `checking`, sacudida al fallar) |
| `Modules/Lock/LockChip.qml` | Píldora de aviso bajo el campo (contraseña incorrecta, Bloq Mayús) |
| `Modules/Lock/LockWeather.qml` | Tarjeta de clima con tres estilos: Pronóstico, Tarjeta y Clásico |
| `Modules/Lock/LockMedia.qml` | Tarjeta del reproductor MPRIS: estilo Reproductor (con espectro) o Clásico |
| `Modules/Lock/LockControls.qml` | Botones anterior / reproducir-pausar / siguiente, compartidos por ambos estilos del reproductor |
| `Modules/Lock/LockNotifs.qml` | Panel de notificaciones de solo lectura (solo apps o solo avisos) |
| `Modules/Lock/LockClock.qml` | Reloj con cinco estilos: clásico, apilado, minimalista, tarjetas y analógico |
| `Modules/Lock/LockContent.qml` | Todo lo visual del bloqueo: coloca los bloques (reloj, acceso, widgets, energía, estado) según la distribución elegida |
| `Modules/Lock/LockLayouts.qml` | Tabla de distribuciones: posición de cada bloque en cada preset |
| `Modules/Lock/LockPower.qml` | Botones Reiniciar / Apagar con confirmación de doble clic |
| `Settings/LockLayoutPicker.qml` | Selector de distribución con miniaturas, dibujadas desde `LockLayouts` |
| `Modules/Lock/LockDashboard.qml` | Panel vertical que reúne clima, reproductor y avisos en un solo contenedor (ver «Dashboard vertical») |
| `Modules/Lock/LockDashSection.qml` | Base de cada sección del dashboard: cabecera, divisor, contenido y animación de altura |
| `Modules/Lock/LockDashWeather.qml` | Sección de clima: actual, métricas y pronóstico con barras de rango |
| `Modules/Lock/LockDashMedia.qml` | Sección del reproductor: pista, espectro, progreso y controles |
| `Modules/Lock/LockDashNotifs.qml` | Sección de avisos: por app o lista detallada |
| `Modules/Lock/LockSpectrum.qml` | Barras del espectro de audio (suavizado con un solo `FrameAnimation`) |
| `Modules/Lock/LockConfig.qml` | Singleton con todas las opciones y su persistencia en `lock.json` |
| `Settings/pages/OozeLockPage.qml` | Página de ajustes de la categoría `oozelock` |
| `Core/Ipc/LockIpc.qml` | Target IPC `lock` |

## Estructura visual de `LockScreen.qml`

La superficie (`WlSessionLockSurface`, una por monitor) se compone de capas, de abajo hacia arriba:

1. **Fondo** — `Image` con el wallpaper + `MultiEffect` (desenfoque, oscurecido). En modo rendimiento se usa un rectángulo negro en lugar del efecto.
2. **Velos** — degradado vertical fijo (más oscuro en los extremos) más una viñeta lateral, para dar contraste al texto sin cargar la GPU.
3. **Entrada de teclado** — `Item` invisible con el foco. Recibe teclas, gestiona Caps Lock y arma `password`.
4. **Contenido** — `LockContent` (ocupa toda la superficie; entrada con opacidad y desplazamiento). Posiciona cinco bloques según `layout` (ver «Distribuciones»):
   - **Reloj** (`clockBlock`): `LockClock` → línea de fecha.
   - **Acceso** (`authBlock`): identidad (avatar, saludo, nombre) → `LockField` → `LockChip` de error → `LockChip` de Caps Lock.
   - **Widgets**, según `widgetsPlacement` y `widgetsStyle`:
     - `top` / `bottom` → `GridLayout id: widgets` con las tarjetas sueltas `LockWeather`, `LockMedia` y `LockNotifs`, en una fila (1, 2 o 3 columnas según el ancho).
     - `left` / `right` con `widgetsStyle = dashboard` (por defecto) → `LockDashboard`, un único panel vertical (ver «Dashboard vertical»).
     - `left` / `right` con `widgetsStyle = cards` → las mismas tarjetas sueltas, apiladas en una columna pegada al borde.
     - `auto` → el lado lo decide la distribución.
     - Si la pantalla es estrecha (ver «Tamaños»), el panel lateral cae a tarjetas abajo.
   - **Energía** (`powerRow`): `LockPower`, opcional.
   - **Estado** (`statusRow`): idioma del teclado y batería.

`LockScreen` se queda con la sesión, PAM, el teclado y el fondo; todo lo demás vive en `LockContent`.

La escala `surface.u` (que `LockScreen` entrega a `LockContent` como `unit`) (alto de pantalla / 1080, entre 0.7 y 1.3) multiplica todas las medidas, así el diseño se adapta a cualquier resolución.

## Distribuciones

`layout` decide dónde va cada bloque de la pantalla. Todo sale de una sola tabla (`LockLayouts.table`); `LockContent` la lee y posiciona los bloques, y el selector de ajustes dibuja las miniaturas desde la misma tabla, así que no pueden desincronizarse.

### Bloques

| Bloque | Qué contiene | Item en `LockContent` |
|---|---|---|
| Reloj | Reloj y fecha | `clockBlock` |
| Acceso | Avatar, nombre, campo de contraseña y avisos | `authBlock` |
| Widgets | Dashboard o tarjetas | `dashboard` / `widgets` |
| Energía | Botones Reiniciar y Apagar (opcional, `showPower`) | `powerRow` |
| Estado | Teclado y batería | `statusRow` |

### Presets

| `layout` | Reloj | Acceso | Estado | Energía | Widgets (modo auto) |
|---|---|---|---|---|---|
| `center` | centro, agrupado con el acceso | centro | centro | abajo der. | abajo (tarjetas) |
| `stack-left` | arriba izq. | izq., a media altura | abajo izq. | abajo der. | derecha |
| `stack-right` | arriba der. | der., a media altura | abajo der. | abajo izq. | izquierda |
| `split-center` | arriba izq. | centro abajo | abajo izq. | abajo der. | derecha |
| `split-right` | arriba izq. | abajo der. | abajo izq. | abajo der. | izquierda, bajo el reloj |
| `split-left` | arriba der. | abajo izq. | abajo der. | arriba izq. | derecha, bajo el reloj |

`center` es la distribución de siempre: reloj y acceso forman una sola columna centrada (`joined: true`). En los demás presets los bloques se colocan por separado y el contenido de cada uno se alinea al lado que le toca (izquierda, centro o derecha).

### Cómo se posiciona

- Cada preset define, por bloque, un lado horizontal `h` (`left`, `center`, `right`) y, cuando aplica, uno vertical `v` (`top`, `middle`, `bottom`).
- `LockContent.px(h, ancho)` convierte el lado en una coordenada x respetando el margen `edge`. En vertical, el reloj va arriba, el acceso a media altura o sobre la franja inferior, y estado y energía pegados al borde.
- **Widgets en modo auto** (`widgetsPlacement = auto`): toman el lado que indica el preset. El dashboard ocupa la zona libre de ese lado: `sideTop` baja si el reloj o los botones de energía están arriba del mismo lado, y `sideBottom` sube si el acceso o la franja de estado están abajo del mismo lado. Si el panel no cabe en esa zona, se escala (ver «Dashboard vertical»).
- Si fuerzas `widgetsPlacement` a un lado concreto, se respeta aunque el preset tenga ahí otro bloque; solo el modo auto garantiza que nada se superponga.
- En pantallas estrechas el panel lateral cae a tarjetas abajo, igual que antes.

### Botones de energía

`showPower` (apagado por defecto) muestra Reiniciar y Apagar en la esquina que define el preset. El primer clic arma el botón (se pone rojo y pregunta «¿Seguro?» durante 3 s); el segundo ejecuta la acción con `PowerActions`. Ojo: cualquiera con acceso físico podría apagar el equipo sin contraseña, igual que en un login manager.

## Dashboard vertical

Con `widgetsPlacement` en `left` o `right` y `widgetsStyle = dashboard`, el clima, el reproductor y los avisos dejan de ser tres tarjetas independientes y pasan a ser **secciones de un solo panel**, igual que un dashboard: un contenedor, una cabecera con el mismo formato en cada sección y divisores finos entre ellas.

```
LockDashboard                      panel de cristal (SkinRect) + velo de color del clima
└─ ColumnLayout "stack"
   ├─ LockDashWeather              sección 1
   │    cabecera:  icono · CLIMA ............ ciudad · región
   │    actual:    icono · temperatura ...... descripción / máx-mín / sensación
   │    métricas:  humedad │ viento │ presión │ lluvia
   │    pronóstico: una fila por día (día · icono · mín ▬▬●▬▬ máx)
   ├─ LockDashMedia                sección 2   (divisor superior si hay clima)
   │    cabecera:  icono · REPRODUCIENDO .... nombre del reproductor
   │    pista:     portada · título / artista
   │    espectro:  LockSpectrum
   │    progreso:  tiempo ▬▬▬ tiempo
   │    controles: LockControls
   └─ LockDashNotifs               sección 3   (divisor superior si hay algo arriba)
        cabecera:  icono · NOTIFICACIONES ... total
        contenido: una fila por app (modo apps) o lista de avisos (modo notifs)
```

### Cómo funciona cada pieza

- **`LockDashSection`** es la base de las tres secciones. Recibe `shown`, `divider`, `icon`, `title` y `trailing` (texto a la derecha de la cabecera). Todo lo que se declare dentro de una sección derivada cae automáticamente en el cuerpo (`content`). Cuando `shown` pasa a falso la sección se desvanece y su alto baja a 0 con animación, así el panel se encoge sin dejar huecos y se vuelve a centrar.
- **`LockDashboard`** compone las secciones, dibuja el cristal y el velo de color del clima (`weatherTint`), y se oculta entero cuando ninguna sección tiene datos (`anyShown`). La propiedad `active` lo apaga cuando el diseño no es dashboard.
- **Ajuste a pantallas bajas**: si el panel es más alto que `maxHeight` (alto de pantalla menos un margen), se reduce con `scale` desde el borde en el que está pegado, así nunca se sale de la pantalla.
- **Pronóstico con rango**: la barra de cada día va de su mínima a su máxima, medidas contra el mínimo y el máximo de todos los días mostrados, para poder comparar días de un vistazo. En la fila de hoy, un punto marca la temperatura actual.
- **Estilos antiguos**: con el dashboard, `weatherStyle`, `mediaStyle` y las escalas por tarjeta (`weatherScale`, `mediaScale`, `notifScale`) no se usan; el tamaño sale de `dashScale` y el ancho de `sideWidth`. Siguen aplicando en el modo `cards`.
- **Opciones que sí se respetan**: `weatherEnabled`, `weatherCity`, `weatherFahrenheit`, `weatherForecast`, `weatherDays`, `weatherTint`, `mediaEnabled`, `mediaCover`, `mediaOnlyPlaying`, `mediaVisualizer`, `notifMode`, `notifMax`.
- **Recursos**: con el dashboard activo, las tarjetas sueltas quedan inactivas (`active: false`, `visualizer: false`), así no hay dos espectros ni dos suscripciones corriendo. `LockScreen` sigue registrando `WeatherService`, `MprisBackend` y `AudioLevels` solo mientras está bloqueado.

## Flujo de autenticación

`lock()` → `sessionLock.locked = true` y `snapProc` copia el wallpaper a `~/.cache/oozeshell/lock-bg-*` → el usuario escribe → `submit()` → `pam.start()` → PAM pide respuesta (`onPamMessage`) y se envía `password` → `onCompleted`: éxito llama a `unlockNow()`, fallo llama a `fail()` y muestra el aviso.

La contraseña vive solo en memoria y se vacía al responder a PAM. Si PAM está ocupado se aborta antes de reintentar.

## Clima

- `LockScreen` registra un watcher `"lock"` en `WeatherService` solo mientras está bloqueado, el clima está activo y hay ciudad (`weatherWanted`). Al desbloquear se retira, así no hay peticiones de red en segundo plano.
- La ciudad sale de `LockConfig.city`: la propia (`weatherCity`) o, si está vacía, la de cualquier widget de escritorio que tenga una (`widgetCity`).
- `LockWeather` lee `WeatherService.get(city)`. Mientras no haya datos la tarjeta permanece oculta; no deja huecos en el layout.
- Estilos (`weatherStyle`), calcados de los widgets de escritorio (`WeatherWidget`):
  - `forecast`: icono, temperatura, descripción y lugar; en tarjetas anchas (≥ 420 u) un bloque a la derecha con máx/mín, sensación, humedad, viento, presión y probabilidad de lluvia; debajo, una celda por día (`weatherDays`, 3–5, la de hoy resaltada). `weatherForecast` oculta la fila de días.
  - `card`: icono, temperatura, descripción y lugar, con tres tiles (sensación, humedad, viento).
  - `classic`: el diseño anterior en una sola fila (o apilado en el panel lateral).
  - `weatherTint` dibuja el velo de color según el clima (mismo cálculo que el widget); no se dibuja en CoOzey ni en `classic`.
- Datos y red: Open-Meteo vía `curl`, sin API key. Detalle del servicio en `WIDGETS.md`.

## Tamaños

Cada tarjeta recibe `unit = surface.u * scale / 100`, así que el porcentaje escala textos, iconos, márgenes y ancho a la vez. En el panel lateral el ancho sale de `sideWidth * u * scale / 100`. El panel lateral solo se usa si la pantalla mide al menos `(960 + sideWidth * escalaMáxima) * u` de ancho; si no, cae a `bottom`. Con escalas altas el panel puede no caber en vertical en pantallas bajas.

## Reloj

`LockClock` recibe `now`, `use24h`, `clockStyle` y `scalePct`. Estilos: `classic`, `stacked` (horas sobre minutos), `mono` (una sola tinta), `boxed` (cada par de dígitos en una tarjeta) y `analog` (esfera con marcas y manecillas, se mueve cada minuto). `clockScale` (60–140) multiplica el tamaño de cualquier estilo. La línea de fecha sigue en `LockScreen` y muestra AM/PM en modo 12 h.

## Notificaciones

- `LockNotifs` lee `NotificationsBackend.list` y no tiene `MouseArea`: no se puede abrir, expandir, ejecutar acciones ni descartar nada.
- `notifMode`:
  - `off`: el panel no aparece.
  - `apps`: una fila por app con su ícono y el número de avisos. No se muestra título ni texto.
  - `notifs`: los `notifMax` avisos más recientes con app, título, hora y hasta dos líneas de cuerpo. Las etiquetas del cuerpo se eliminan.
- El panel se oculta solo (`opacity` 0) cuando no hay avisos.

## Reproductor MPRIS

- Estilos (`mediaStyle`): `player` copia el estilo *player* de `AudioVisualizerWidget` (portada grande, título, artista, barras del espectro con degradado, progreso con tiempos) y añade los controles; `classic` es la tarjeta anterior.
- Espectro (`mediaVisualizer`): `LockMedia` suaviza `AudioLevels.bands` con un solo `FrameAnimation` que se detiene cuando las barras se asientan. `LockScreen` registra `AudioLevels.setWanted("lock", …)` solo mientras está bloqueado, el estilo es `player`, el espectro está activo y la reproducción está en `Playing`, así `cava` no corre en otros casos. Requiere `cava`; sin él las barras quedan planas.
- `LockMedia` consume `MprisBackend` (ver `MPRIS.md`). Los controles son `MouseArea` reales: anterior, reproducir/pausar y siguiente, clic en la portada para reproducir/pausar y clic en la barra para saltar a una posición.
- `LockScreen` registra `MprisBackend.setWanted("lock", …)` solo mientras está bloqueado y el reproductor está activo, para que la posición se actualice sin consumir de más.
- Con `mediaOnlyPlaying` la tarjeta se oculta si la reproducción está en pausa.
- Los clics no roban el foco: el teclado sigue escribiendo la contraseña.

## Opciones (`LockConfig`)

Archivo: `~/.config/oozeshell/lock.json`. La escritura se retrasa 400 ms y el archivo se vigila, así que se puede editar a mano. Cada opción se declara una sola vez en `schema` (tipo, límites, valor por defecto).

| Clave | Tipo / rango | Defecto | Efecto |
|---|---|---|---|
| `bgBlur` | 0–100 | 45 | Desenfoque del fondo |
| `bgDim` | 0–80 | 18 | Oscurecido del fondo |
| `clock24h` | bool | true | Reloj de 24 h o 12 h (con AM/PM en la línea de fecha) |
| `clockStyle` | `classic` \| `stacked` \| `mono` \| `boxed` \| `analog` | `classic` | Estilo del reloj |
| `clockScale` | 60–140 | 100 | Tamaño del reloj en % |
| `showDate` | bool | true | Línea de fecha |
| `showAvatar` | bool | true | Avatar, saludo y nombre |
| `showLayout` | bool | true | Idioma del teclado |
| `showBattery` | bool | true | Batería (solo si el equipo tiene) |
| `layout` | `center` \| `stack-left` \| `stack-right` \| `split-center` \| `split-right` \| `split-left` | `center` | Distribución de los bloques (ver «Distribuciones») |
| `showPower` | bool | `false` | Botones Reiniciar y Apagar en el bloqueo |
| `widgetsPlacement` | `auto` \| `top` \| `bottom` \| `left` \| `right` | `auto` | Dónde van clima, reproductor y notificaciones; `auto` sigue la distribución |
| `widgetsStyle` | `dashboard` \| `cards` | `dashboard` | Con `left`/`right`: un solo panel vertical o tarjetas sueltas |
| `dashScale` | 60–140 | 100 | Tamaño del dashboard en % (solo con `widgetsStyle = dashboard`) |
| `sideWidth` | 260–460 | 340 | Ancho base del panel lateral (dashboard o tarjetas) |
| `weatherEnabled` | bool | true | Tarjeta de clima |
| `weatherScale` | 60–140 | 100 | Tamaño de la tarjeta de clima en % |
| `weatherCity` | texto | vacío | Ciudad, `Ciudad, País` o `lat,lon` |
| `weatherFahrenheit` | bool | false | °F y mph |
| `weatherRefreshMin` | 10–120 | 30 | Minutos entre actualizaciones |
| `weatherForecast` | bool | true | Fila de días del pronóstico |
| `weatherStyle` | `forecast` \| `card` \| `classic` | `forecast` | Diseño de la tarjeta de clima |
| `weatherDays` | 3–5 | 5 | Días en el estilo Pronóstico (incluye hoy) |
| `weatherTint` | bool | true | Velo de color según el clima |
| `mediaEnabled` | bool | true | Tarjeta del reproductor |
| `mediaScale` | 60–140 | 100 | Tamaño de la tarjeta del reproductor en % |
| `mediaOnlyPlaying` | bool | false | Ocultar si está en pausa |
| `mediaCover` | bool | true | Portada del álbum |
| `mediaStyle` | `player` \| `classic` | `player` | Diseño de la tarjeta del reproductor |
| `mediaVisualizer` | bool | true | Espectro de audio en el estilo Reproductor |
| `notifMode` | `off` \| `apps` \| `notifs` | `apps` | Panel de notificaciones: nada, solo apps o solo avisos |
| `notifMax` | 1–6 | 4 | Apps o avisos visibles en el panel |
| `notifScale` | 60–140 | 100 | Tamaño del panel de notificaciones en % |

El fondo (`lockWallpaper`, `lockWallpaperPath`) sigue guardándose en `ui.json` vía `Theme`, pero ahora se edita desde la página OozeLock, no desde General.

## IPC

Target `lock` (`Core/Ipc/LockIpc.qml`):

| Función | Efecto |
|---|---|
| `lock` | cierra popups y bloquea (`lockScreen.lock()`) |
| `locked` | devuelve `bool` con el estado de bloqueo |
| `get` | JSON con todas las opciones de OozeLock |
| `set <clave> <valor>` | cambia una opción con validación; devuelve `true` si se aplicó |
| `reset` | restaura las opciones a sus valores por defecto (no toca el fondo) |

```sh
quickshell ipc -p .../shell.qml call -- lock lock
quickshell ipc -p .../shell.qml call -- lock get
quickshell ipc -p .../shell.qml call -- lock set weatherCity "La Paz, Mexico"
quickshell ipc -p .../shell.qml call -- lock set widgetsPlacement right
quickshell ipc -p .../shell.qml call -- lock set layout split-right
quickshell ipc -p .../shell.qml call -- lock set showPower true
quickshell ipc -p .../shell.qml call -- lock set widgetsStyle cards
quickshell ipc -p .../shell.qml call -- lock set dashScale 110
quickshell ipc -p .../shell.qml call -- lock set clockStyle analog
quickshell ipc -p .../shell.qml call -- lock set notifMode notifs
quickshell ipc -p .../shell.qml call -- lock set weatherStyle card
quickshell ipc -p .../shell.qml call -- lock set mediaVisualizer false
```

## Cómo extender

- **Nueva opción**: añadir su entrada en `LockConfig.schema` + su `property`, usarla en `LockScreen`, y agregar la fila en `OozeLockPage.qml` con sus claves de traducción (EN/ES) y su entrada en `SettingsRegistry` para el buscador.
- **Nueva distribución**: añadir su id a `LockLayouts.ids` y su entrada a `LockLayouts.table` (más el valor en el enum `layout` de `LockConfig`, y una clave `olLayoutXxx` en `LangEs`/`LangEn` con su nombre en `LockLayoutPicker.names`). `LockContent` y el selector la usan sin más cambios.
- **Nueva sección del dashboard**: crear `LockDashXxx.qml` como `LockDashSection { ... }` (define `shown`, `icon`, `title` y, si quiere, `trailing`; el contenido va directamente dentro), registrarlo en `qmldir` y añadirlo al `ColumnLayout id: stack` de `LockDashboard` con su `divider` (`true` si hay alguna sección visible encima).
- **Nuevo widget** (modo tarjetas): crear `LockXxx.qml` con las props `unit` y `active` (como `LockWeather`), registrarlo en `qmldir` y añadirlo al `GridLayout id: widgets`. Debe ocultarse solo (`opacity` 0) cuando no tenga datos.

## Dependencias y notas

- Importa `COMMON`, `Services/Lang`, `Services/Battery`, `Services/Mpris`, `AudioLevels` (de `COMMON`), `Services/Notify` (solo `NotificationsBackend`, desde `LockNotifs` y `LockDashNotifs`) y `Modules/Widgets` (solo `WeatherService`, `WeatherIcon` y `WidgetConfig`).
- `Quickshell.Wayland` (`WlSessionLock`), `Quickshell.Services.Pam` y `Quickshell.Io`.
- Animaciones con `Theme.animDuration`, sin bucles continuos. La detección de Caps Lock usa un `Process` que solo corre mientras hay bloqueo.
