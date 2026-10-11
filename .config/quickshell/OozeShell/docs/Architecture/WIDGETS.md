# WIDGETS — widgets de escritorio

- Qué es
  - Widgets flotantes de escritorio (reloj, sistema, visualizador, marco de imagen, clima, pomodoro). `WidgetHost.qml` (Scope con IPC `widgets`) crea una `WidgetWindow` por widget activo; `WidgetConfig` guarda el estado; `WidgetRegistry` es el catálogo de tipos.
- Archivos
  - `WIDGETS/WidgetHost.qml` → Scope raíz + `IpcHandler target "widgets"` (`list/types/add/remove/enable/disable/toggle/style/move/size/monitor/option/pomodoro/layer/edit/raise`).
  - `WIDGETS/WidgetRegistry.qml` → singleton: `types[]` (id/title/source/styles/size/styleSizes/defaults/ranges/pickers/needsNative), `get/has/sizeFor`. EL anexador: dar de alta un tipo es añadir una entrada aquí.
  - `WIDGETS/WidgetConfig.qml` → singleton: `widgets[]/byId/enabledIds`, `layer` (`bottom|background`), `widgetsEnabled/globalOpacity/globalBlur`, `add/remove/update/setStyle/setOption/setLayer`, `save/load/serialize/normalize/rebuild` + señal `raiseRequested`.
  - `WIDGETS/WidgetWindow.qml` → ventana por widget (mover/redimensionar en `editMode`).
  - `WIDGETS/WidgetBase.qml` → base de cada widget (`cfg/editMode`, `widgetId/widgetStyle/options`, `opt(key,def)`, `blurStrength`).
  - `WIDGETS/WidgetCard.qml`, `WidgetBlur.qml`, `WidgetBackdrop.qml` (singleton: fondo `~/.cache/awww/last`) → piezas visuales.
  - `WIDGETS/clock/ClockWidget.qml`, `sysinfo/SysInfoWidget.qml`, `audiovisualizer/AudioVisualizerWidget.qml`, `imageframe/ImageFrameWidget.qml`, `weather/WeatherWidget.qml` + `WeatherService.qml` + `WeatherIcon.qml`, `pomodoro/PomodoroWidget.qml` + `PomodoroService.qml` → los 6 tipos.
  - `WIDGETS/qmldir` → declara singletons (`WidgetRegistry`, `WidgetConfig`, `WidgetBackdrop`, `WeatherService`) y componentes (`WidgetBase`, `WidgetCard`, `WidgetBlur`, `WidgetWindow`, `WidgetHost`).
- IPC
  | target | función | efecto |
  |---|---|---|
  | `widgets` | `list` / `types` | lista instancias / tipos con estilos |
  | `widgets` | `add <tipo> <estilo>` / `remove <id>` | crear (devuelve id) / borrar |
  | `widgets` | `enable` / `disable` / `toggle <id>` | on/off |
  | `widgets` | `style <id> <estilo>` / `move <id> x y` / `size <id> w h` / `monitor <id> <nombre>` | geometría |
  | `widgets` | `option <id> <clave> <valor>` | opción (convierte `true/false`/número) |
  | `widgets` | `pomodoro <id> toggle\|skip\|reset\|restart` | control del pomodoro |
  | `widgets` | `layer bottom\|background` / `edit true\|false` / `raise` | capa / modo edición / traer al frente |

  ```bash
  quickshell ipc -c OozeShell call widgets list
  quickshell ipc -c OozeShell call widgets types
  quickshell ipc -c OozeShell call widgets add clock minimal
  quickshell ipc -c OozeShell call widgets option <id> seconds true
  ```
- Estado y datos
  - Singletons: `WidgetRegistry`, `WidgetConfig`, `WidgetBackdrop`, `WeatherService`, `PomodoroService` (`pragma Singleton`).
  - Persistencia en `~/.config/oozeshell/widgets.json` (`WidgetConfig.file = Theme.prefsDir + "/widgets.json"`): `{version, layer, widgetsEnabled, globalOpacity, globalBlur, widgets[]}`. Escritura con retardo 400 ms vía `writer` (`mv` atómico); lectura con `FileView watchChanges`.
  - `normalize()` fusiona `options` con `defaults` del tipo y recalcula tamaño con `sizeFor(type,style)`; `rebuild()` deriva `byId/enabledIds/allIds` (ignora tipos desconocidos).
- Dependencias
  - `WidgetHost` importa `../COMMON`, `../LANG`, `./pomodoro`; `WidgetConfig` importa `../COMMON` (`Theme.prefsDir`); cada widget lee `Theme` + `Translations`.
- Notas — cómo dar de alta un tipo nuevo vía WidgetRegistry
  1. Crear `WIDGETS/<tipo>/<Tipo>Widget.qml` basado en `WidgetBase` (leer opciones con `w.opt("clave", defecto)`).
  2. Añadir entrada en `WidgetRegistry.types`: `{id, title, source, styles[], size:[w,h], styleSizes:{}, defaults:{}, ranges:{}, pickers:{}}` (+ `needsNative:false`).
  3. Si necesita servicio con estado (clima/pomodoro), añadir singleton `<Tipo>Service.qml` y declararlo en `qmldir`; la página `SETTINGS/pages/WidgetsPage.qml` lo lista solo con `defaults/ranges/pickers` (sin tocar UI).
