# SETTINGS — ajustes rápidos, ajustes avanzados e idioma

- Qué es
  - Tres piezas: paneles rápidos sueltos (`BarSettings`, `LauncherSettings`, `TerminalSettings`, `TodoAlarmSettings`), ventana grande `AdvancedSettings.qml` (categorías de `SettingsRegistry` + páginas en `Settings/pages/`), e idioma (`Services/Lang/Translations` + `LanguagePicker`).
  - `Core/Ipc/SettingsIpc.qml` y `Core/Ipc/LangIpc.qml` exponen los targets IPC `settings` (niveles de UI) y `lang` (idioma); la ventana avanzada cuelga del flag `advancedSettingsOpen`.
- Archivos
  - `Settings/AdvancedSettings.qml` → ventana de tamaño fijo según `Theme.settingsSizes` (`open/targetScreen/category/query`): sidebar agrupado por `group`, buscador con índice (`searchIndex/searchHay/searchResults`), navegación por teclado `kb*`, editor HyprMonitors (`hm*` → `monitors.lua` + `hyprctl reload`). Es la única categoría que sigue inline; el resto vive en `Settings/pages/`.
  - `Settings/SettingsRegistry.qml` → singleton: `allCategories[]` (id/group/icon/titleKey/page/sections con keywords, en el orden del sidebar), `groupLabel(group)`, `byId/iconOf/titleKeyOf/pageOf`, `searchEntries`.
  - `Settings/pages/` → páginas migradas: `AboutPage`, `AgendaPage`, `AppearancePage`, `AudioPage`, `BarPage`, `DefaultAppsPage` (ver DEFAULTAPPS.md), `DockPage`, `GeneralPage`, `GlobalManagerPage`, `InterfacePage`, `KeybindsPage`, `LauncherPage`, `OozeLockPage` (ver LOCK.md), `PowerMenuPage`, `ProfilePage`, `QuickBarPage`, `ServicesPage`, `WallpapersPage`, `WidgetsPage`.
  - `Settings/WidgetQuickSettings.qml` → panel lateral compacto de ajustes de widgets (ver WIDGETS.md). Ventana layer-shell pegada a un borde (`WidgetConfig.quickSide`), del ancho justo (`380 × Theme.settingsTextScale` px) y sin máscara fuera del panel, así el resto del escritorio sigue interactivo. Se cierra solo con Esc o con su botón; el botón de flecha cambia el lado.
  - `Settings/pages/WidgetEditorBody.qml` → cuerpo de edición de un widget (estilo, monitor, posición/tamaño, opciones); lo comparten `WidgetsPage` y `WidgetQuickSettings`. `Settings/pages/WidgetOptionGroup.qml` y `Settings/pages/WidgetGlobalRow.qml` son sus piezas.
  - `Settings/BarSettings.qml`, `Settings/LauncherSettings.qml`, `Settings/TerminalSettings.qml`, `Settings/TodoAlarmSettings.qml` → paneles rápidos independientes (`open/targetScreen`).
  - `Settings/SettingsPage.qml`, `Settings/SettingsSection.qml`, `Settings/SettingsBtn.qml`, `Settings/SettingsPanelTitle.qml` → piezas reutilizables de las páginas.
  - Estructura común de toda página: `SettingsSection` (título + descripción) → `SettingsRow` (etiqueta y descripción a la izquierda, control a la derecha; `stacked` baja el control debajo) → control. Controles: `SettingsSwitch` (booleanos), `SettingsChoice` (2-4 opciones), `SettingsChips` (muchas opciones), `ScaleSlider`, `NumberStepper`, `LevelPicker`, `SettingsField`, `SettingsBtn`/`SettingsIconBtn` (acciones), `SettingsValue` (solo lectura) y `SettingsNote` (avisos). Orden dentro de una página: motor/estado → posición/layout → apariencia → comportamiento → avanzado/herramientas. Las filas deben conservar su `titleKey`: la búsqueda salta a ellas por texto.
  - `Settings/FontPicker.qml`, `Settings/LevelPicker.qml` (`count` = nº de segmentos fijos, 5 por defecto), `Settings/ScaleSlider.qml`, `Settings/NumberStepper.qml`, `Settings/ImageBrowser.qml` → controles reutilizables.
  - `Services/Lang/Translations.qml` → singleton: `current` (`"en"` por defecto), packs `LangEn/LangEs`, `t(key)`/`tw(key,wm)`/`sections()`/`vimSections()`, `availableLanguages`, `localeCode` (`en_US`/`es_ES`, para fechas con `Qt.locale(...)`).
  - `Services/Lang/LanguagePicker.qml` → selector (`open/current/targetScreen`, señal `languageChosen(code)`).
  - `Services/Lang/languages/` → `LangEn.qml`, `LangEs.qml` (un objeto con `code/name/strings/sections/vimSections` cada uno).
- IPC (Core/Ipc/SettingsIpc.qml target `settings`, Core/Ipc/LangIpc.qml target `lang`):
  | target | función | efecto |
  |---|---|---|
  | `settings` | `toggle` / `open` / `close` | ventana de ajustes avanzados |
  | `settings` | `get` | JSON `{font,bar,window,settingsSize}` (niveles `Theme` + tamaño de la ventana de ajustes: `min\|compact\|normal\|large`) |
  | `settings` | `setUi <n>` | `Theme.setInterfaceLevel(n)` (barra + ventanas) |
  | `settings` | `setLevel font\|bar\|window <n>` | `Theme.setLevel(kind,level)` |
  | `settings` | `reset` | `Theme.resetLevels()` |
  | `settings` | `setSize <0-3>` / `resetWindow` | tamaño de la ventana de ajustes (0 mínimo · 1 compacto · 2 normal · 3 grande) |
  | `lang` | `set <code>` / `get` / `list` / `togglePicker` | idioma (`en/es`) |

  ```bash
  quickshell ipc -p .../shell.qml call -- settings toggle
  quickshell ipc -p .../shell.qml call -- settings setLevel font 4
  quickshell ipc -p .../shell.qml call -- lang set es
  quickshell ipc -p .../shell.qml call -- lang list
  ```
- Estado y datos
  - Singletons: `SettingsRegistry`, `Translations` (`pragma Singleton`). Niveles y preferencias viven en `Theme` (`~/.config/oozeshell/ui.json`, `prefsDir = $HOME/.config/oozeshell` en `COMMON/Theme.qml:1916`).
  - Idioma: `shell.qml` guarda `currentLang` con `StateStore.set("lang", code)` en `~/.cache/oozeshell/state.json` (`Core/StateStore.qml`); `onCurrentLangChanged` lo propaga a `Translations.current`, lo que re-evalúa todos los `t()` por binding.
  - `AdvancedSettings` no persiste nada propio: escribe a través de `Theme`, `WM`, `AudioService` y genera `~/.config/hypr/modules/hardware/settings/monitors.lua`.
- Dependencias
  - `SettingsRegistry` importa `Services/Lang` + `COMMON`; `AdvancedSettings` importa `COMMON`, `Services/Lang`, `Services/Agenda`, `Modules/Appearance`, `Services/OozeAudio/data`, `Services/Audio`.
  - `Translations` importa `languages` (los 2 packs); claves nuevas de sidebar: `setGroupUser/Look/Desktop/System`, `setEnable`, `setGeneral`; categorías con `requires: "monitorEditor"` se filtran por `WM.has()`.
- Notas
  - Añadir categoría = una entrada en `SettingsRegistry.allCategories` (+ `Settings/pages/<Nombre>Page.qml` si necesita página propia); el buscador la indexa solo con `titleKey/sections/rows` y keywords `kw`.
  - Añadir idioma = nuevo `LangXx.qml` con las mismas claves + pack en `Translations.qml`; las claves sin traducir devuelven la clave (`t()` filtra `searchIndex` así).

- `Settings/pages/OozeLockPage.qml` (categoría `oozelock`, grupo Escritorio) agrupa todo lo de la pantalla de bloqueo: fondo (modo, imagen, desenfoque, oscurecido), reloj e información, posición de widgets, clima y reproductor. Las opciones viven en `LockConfig` (`~/.config/oozeshell/lock.json`); el fondo sigue en `Theme`. `GeneralPage` ya no contiene la sección de bloqueo.

- `Settings/pages/BarPage.qml` incluye la sección **Módulos** (picker de qué va en cada isla de la barra y en qué orden); ver `Docs/Architecture/BAR.md`.

- Tamaño de la ventana de ajustes (4 niveles fijos)
  - `Theme.settingsSizes` define cada nivel: `w/h` de la ventana, `content` (ancho máximo del detalle) y `text` (multiplicador de fuente). Se elige en Interfaz → Ventana de ajustes con un `LevelPicker` de 4 segmentos y se guarda en `ui.json` como `settingsSize` (0-3, por defecto 2).
  - No hay escalado artificial: `AdvancedSettings.winW/winH` son píxeles reales (limitados al área libre de la pantalla) y el texto usa `Theme.sfs(px)` = `round(px × fontScale × settingsTextScale)`, un `pixelSize` entero que Qt rasteriza nítido. Todos los controles de `Settings/` usan `sfs`; `SectionLabel` recibe `textScale: Theme.settingsTextScale`. Los paneles sueltos `BarSettings`, `LauncherSettings` y `TerminalSettings` siguen con `Theme.fs`.
  - La ventana mide lo mismo que su tarjeta y su máscara de entrada es solo la tarjeta: ya no hay capa a pantalla completa, por eso un clic fuera no la cierra. Se cierra con Esc o con su botón.
  - Foco de teclado: `Exclusive` los primeros 250 ms tras abrir (para que Esc y escribir funcionen al instante) y luego `OnDemand`, de modo que al hacer clic en otra ventana o widget el teclado vuelve a ella.
