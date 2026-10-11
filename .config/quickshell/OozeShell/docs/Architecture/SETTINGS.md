# SETTINGS — ajustes rápidos, ajustes avanzados e idioma

- Qué es
  - Tres piezas: paneles rápidos sueltos (`BarSettings`, `LauncherSettings`, `TerminalSettings`, `TodoAlarmSettings`), ventana grande `AdvancedSettings.qml` (categorías de `SettingsRegistry` + páginas en `SETTINGS/pages/`), e idioma (`LANG/Translations` + `LanguagePicker`).
  - `shell.qml` expone los targets IPC `settings` (niveles de UI) y `lang` (idioma); la ventana avanzada cuelga del flag `advancedSettingsOpen`.
- Archivos
  - `SETTINGS/AdvancedSettings.qml` → ventana 960×660 (`open/targetScreen/category/query`): sidebar, buscador con índice (`searchIndex/searchHay/searchResults`), navegación por teclado `kb*`, editor HyprMonitors (`hm*` → `monitors.lua` + `hyprctl reload`).
  - `SETTINGS/SettingsRegistry.qml` → singleton: `allCategories[]` (id/icon/titleKey/page/sections con keywords), `byId/iconOf/titleKeyOf/pageOf`, `searchEntries`.
  - `SETTINGS/pages/` → 11 páginas migradas: `AboutPage`, `AgendaPage`, `BarPage`, `GlobalManagerPage`, `KeybindsPage`, `LauncherPage`, `PowerMenuPage`, `QuickBarPage`, `ServicesPage`, `WallpapersPage`, `WidgetsPage`.
  - `SETTINGS/BarSettings.qml`, `LauncherSettings.qml`, `TerminalSettings.qml`, `TodoAlarmSettings.qml` → paneles rápidos independientes (`open/targetScreen`).
  - `SETTINGS/SettingsPage.qml`, `SettingsSection.qml`, `SettingsBtn.qml`, `SettingsPanelTitle.qml` → piezas reutilizables de las páginas.
  - `SETTINGS/FontPicker.qml`, `LevelPicker.qml`, `ScaleSlider.qml`, `NumberStepper.qml`, `ImageBrowser.qml` → controles reutilizables.
  - `LANG/Translations.qml` → singleton: `current` (`"en"` por defecto), packs `LangEn/LangEs/LangId/LangJa`, `t(key)`/`tw(key,wm)`/`sections()`/`vimSections()`, `availableLanguages`.
  - `LANG/LanguagePicker.qml` → selector (`open/current/targetScreen`, señal `languageChosen(code)`).
  - `LANG/languages/` → `LangEn.qml`, `LangEs.qml`, `LangId.qml`, `LangJa.qml` (un objeto con `code/name/strings/sections/vimSections` cada uno).
- IPC
  | target | función | efecto |
  |---|---|---|
  | `settings` | `toggle` / `open` / `close` | ventana de ajustes avanzados |
  | `settings` | `get` | JSON `{font,bar,window}` (niveles `Theme`) |
  | `settings` | `setUi <n>` | `Theme.setInterfaceLevel(n)` (barra + ventanas) |
  | `settings` | `setLevel font\|bar\|window <n>` | `Theme.setLevel(kind,level)` |
  | `settings` | `reset` | `Theme.resetLevels()` |
  | `lang` | `set <code>` / `get` / `list` / `togglePicker` | idioma (`en/es/id/ja`) |

  ```bash
  quickshell ipc -p .../shell.qml call -- settings toggle
  quickshell ipc -p .../shell.qml call -- settings setLevel font 4
  quickshell ipc -p .../shell.qml call -- lang set es
  quickshell ipc -p .../shell.qml call -- lang list
  ```
- Estado y datos
  - Singletons: `SettingsRegistry`, `Translations` (`pragma Singleton`). Niveles y preferencias viven en `Theme` (`~/.config/oozeshell/ui.json`, `prefsDir = $HOME/.config/oozeshell` en `COMMON/Theme.qml:1651`).
  - Idioma: `shell.qml` guarda `currentLang` en `~/.cache/oozeshell-lang` (`langCacheFile`, `shell.qml:823`); `onCurrentLangChanged` lo propaga a `Translations.current`, lo que re-evalúa todos los `t()` por binding.
  - `AdvancedSettings` no persiste nada propio: escribe a través de `Theme`, `WM`, `AudioService` y genera `~/.config/hypr/modules/hardware/settings/monitors.lua`.
- Dependencias
  - `SettingsRegistry` importa `../LANG` + `../COMMON`; `AdvancedSettings` importa `../COMMON`, `../LANG`, `../AGENDA`, `../APPEARANCE`, `../OozeAudio/data`, `../AUDIO`.
  - `Translations` importa `languages` (los 4 packs); categorías con `requires: "monitorEditor"` se filtran por `WM.has()`.
- Notas
  - Añadir categoría = una entrada en `SettingsRegistry.allCategories` (+ `pages/XPage.qml` si necesita página propia); el buscador la indexa solo con `titleKey/sections/rows` y keywords `kw`.
  - Añadir idioma = nuevo `LangXx.qml` con las mismas claves + pack en `Translations.qml`; las claves sin traducir devuelven la clave (`t()` filtra `searchIndex` así).
