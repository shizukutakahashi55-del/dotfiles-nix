# WIDGETS — widgets de escritorio

- Qué es
  - Widgets flotantes de escritorio (reloj, sistema, visualizador, marco de imagen, clima, pomodoro). `WidgetHost.qml` (Scope con IPC `widgets`) crea una `WidgetWindow` por widget activo; `WidgetConfig` guarda el estado (incluye el estado en memoria del panel rápido `quickOpen/quickId/quickMonitor` y del menú contextual `menuOpen/menuId/menuMonitor/menuX/menuY`); `WidgetRegistry` es el catálogo de tipos.
- Archivos
  - `Modules/Widgets/WidgetHost.qml` → Scope raíz + `IpcHandler target "widgets"` (`list/types/add/remove/enable/disable/toggle/style/move/size/monitor/option/pomodoro/layer/edit/raise`).
  - `Modules/Widgets/WidgetRegistry.qml` → singleton: `types[]` (id/title/source/styles/size/styleSizes/defaults/ranges/styleOptions/pickers/needsNative), `get/has/sizeFor/optionVisible`. EL anexador: dar de alta un tipo es añadir una entrada aquí; `styleOptions` limita una opción a ciertos estilos (el editor la oculta en el resto).
  - `Modules/Widgets/WidgetConfig.qml` → singleton: `widgets[]/byId/enabledIds`, `layer` (`bottom|background`), `widgetsEnabled/globalOpacity/globalBlur`, `add/remove/update/setStyle/setOption/setLayer`, `save/load/serialize/normalize/rebuild/clampToScreen` + señales `raiseRequested` y `widgetRemoved(id)`.
  - `Modules/Widgets/WidgetWindow.qml` → ventana por widget (mover/redimensionar en `editMode`).
  - `Modules/Widgets/WidgetBase.qml` → base de cada widget (`cfg/editMode`, `widgetId/widgetStyle/options`, `opt(key,def)`, `blurStrength`, `blurItems`, `registerBlur/unregisterBlur`).
  - Ajustes rápidos (panel lateral): `Settings/WidgetQuickSettings.qml` (ver SETTINGS.md) montado en `shell.qml` con un `LazyPopup` que escucha `WidgetConfig.quickOpen`. Dos formas de abrirlo: clic derecho sobre un widget (menú con «Ajustes rápidos», dibujado por `WidgetHost`) o el botón «Abrir» en Ajustes avanzados → Widgets (también `widgets quick open`).
  - Clic derecho: `WidgetWindow.contextArea` (solo botón derecho, el clic izquierdo sigue a los controles del widget) llama a `WidgetConfig.openMenu(id, monitor, x, y)`. La máscara de entrada de la ventana es ahora siempre el marco del widget, para poder recibir ese clic.
  - `Modules/Widgets/WidgetCard.qml`, `Modules/Widgets/WidgetBlur.qml`, `Modules/Widgets/WidgetBorder.qml` → piezas visuales. `WidgetBlur` no dibuja nada: registra su silueta en `WidgetBase.blurItems` y `WidgetWindow` la convierte en `BackgroundEffect.blurRegion` (blur real del compositor, funciona con wallpaper animado; la intensidad la fija el WM y la opción `blur` solo activa/desactiva). `WidgetBorder` dibuja el anillo con degradado alrededor del widget.
  - `Modules/Widgets/clock/ClockWidget.qml`, `Modules/Widgets/sysinfo/SysInfoWidget.qml`, `Modules/Widgets/audiovisualizer/AudioVisualizerWidget.qml`, `Modules/Widgets/imageframe/ImageFrameWidget.qml`, `Modules/Widgets/weather/WeatherWidget.qml` + `Modules/Widgets/weather/WeatherService.qml` + `Modules/Widgets/weather/WeatherIcon.qml`, `Modules/Widgets/pomodoro/PomodoroWidget.qml` + `Modules/Widgets/pomodoro/PomodoroService.qml` → los 6 tipos.
  - `WeatherService` también lo usa OozeLock (`Modules/Lock/LockWeather.qml`, watcher `"lock"`; ver LOCK.md).
  - `Modules/Widgets/qmldir` → declara singletons (`WidgetRegistry`, `WidgetConfig`, `WeatherService`) y componentes (`WidgetBase`, `WidgetCard`, `WidgetBlur`, `WidgetBorder`, `WidgetWindow`, `WidgetHost`).
- IPC (Modules/Widgets/WidgetHost.qml target `widgets`)
  | target | función | efecto |
  |---|---|---|
  | `widgets` | `list` / `types` | lista instancias / tipos con estilos |
  | `widgets` | `add <tipo> <estilo>` / `remove <id>` | crear (devuelve id) / borrar |
  | `widgets` | `enable` / `disable` / `toggle <id>` | on/off |
  | `widgets` | `style <id> <estilo>` / `move <id> x y` / `size <id> w h` / `monitor <id> <nombre>` | geometría |
  | `widgets` | `option <id> <clave> <valor>` | opción (convierte `true/false`/número) |
  | `widgets` | `pomodoro <id> toggle\|skip\|reset\|restart` | control del pomodoro |
  | `widgets` | `layer bottom\|background` / `edit true\|false` / `raise` | capa / modo edición / traer al frente |
  | `widgets` | `freemove true\|false` / `arrange` / `border all\|none\|individual` | movimiento libre desde el escritorio / reordenar sin overlap / borde global |
  | `widgets` | `quick open\|close\|toggle\|left\|right\|side` | panel de ajustes rápidos: abrir/cerrar y lado |

  ```bash
  quickshell ipc -c OozeShell call widgets list
  quickshell ipc -c OozeShell call widgets types
  quickshell ipc -c OozeShell call widgets add clock minimal
  quickshell ipc -c OozeShell call widgets option <id> seconds true
  ```
- Estado y datos
  - Singletons: `WidgetRegistry`, `WidgetConfig`, `WeatherService`, `PomodoroService` (`pragma Singleton`).
  - Persistencia en `~/.config/oozeshell/widgets.json` (`WidgetConfig.file = Theme.prefsDir + "/widgets.json"`): `{version, layer, widgetsEnabled, globalOpacity, globalBlur, globalBorder, freeMove, widgets[]}`. Campo nuevo `quickSide` (`left|right`, lado del panel rápido). Escritura con retardo 400 ms vía `writer` (`mv` atómico); lectura con `FileView watchChanges`.
  - `normalize()` fusiona `options` con `defaults` del tipo y recalcula tamaño con `sizeFor(type,style)`; `rebuild()` deriva `byId/enabledIds/allIds` (ignora tipos desconocidos). `clampToScreen()` recoloca un widget si su pantalla encogió o desapareció (se aplica al añadir, al cargar y al cambiar de monitor).
  - Pomodoro: estado en memoria por id (`PomodoroService.states`, el dashboard usa el id virtual `dashboard`); el aviso sale por `NotificationsBackend.pushAlarm` (respeta «no molestar») y el sonido por `pw-play/paplay/canberra`; al borrar un widget se descarta su estado (`WidgetConfig.widgetRemoved`).
- Dependencias
  - `WidgetHost` importa `COMMON`, `Services/Lang`, `Modules/Widgets/pomodoro`; `WidgetConfig` importa `COMMON` (`Theme.prefsDir`); cada widget lee `Theme` + `Translations`.
- Notas — cómo dar de alta un tipo nuevo vía WidgetRegistry
  1. Crear `Modules/Widgets/<tipo>/<Tipo>Widget.qml` basado en `WidgetBase` (leer opciones con `w.opt("clave", defecto)`).
  2. Añadir entrada en `WidgetRegistry.types`: `{id, title, source, styles[], size:[w,h], styleSizes:{}, defaults:{}, ranges:{}, pickers:{}}` (+ `needsNative:false`).
  3. Si necesita servicio con estado (clima/pomodoro), añadir singleton `<Tipo>Service.qml` y declararlo en `qmldir`; la página `Settings/pages/WidgetsPage.qml` lo lista solo con `defaults/ranges/pickers` (sin tocar UI).
