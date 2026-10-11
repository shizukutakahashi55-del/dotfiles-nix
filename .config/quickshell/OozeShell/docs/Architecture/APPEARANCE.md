# APPEARANCE — Panel de estética del WM (gaps, bordes, blur, layout)

- Qué es: popup lateral que edita el objeto `appearance` de `shell.qml` con preview en vivo y commit al WM vía `WmAppearance`. Cubre sliders numéricos, toggles y layout.
- Archivos:
  - `APPEARANCE/Appearance.qml` → popup `FusedWindow`/`FusedPanel`: `sliderSpecs` (gaps, bordes, rounding, opacidades, blur, sombra), `toggleSpecs`, chips de layout; emite `previewChanged`/`valueCommitted`/`toggleChanged`/`layoutChosen`.
  - `APPEARANCE/AppearanceSlider.qml` → slider reutilizable con arrastre, nudges de teclado, edición numérica tipada y commit diferido (350 ms).
- IPC:

  | target | función | efecto |
  |---|---|---|
  | `appearance` | `toggle` | abre/cierra el popup |
  | `appearance` | `get` | devuelve JSON del objeto `appearance` |
  | `appearance` | `set <key> <valor>` | `layout`/`animProfile` directos; toggles con `true/1`; resto como float |

  ```bash
  quickshell ipc -p .../shell.qml call -- appearance toggle
  quickshell ipc -p .../shell.qml call -- appearance get
  quickshell ipc -p .../shell.qml call -- appearance set rounding 14
  quickshell ipc -p .../shell.qml call -- appearance set layout dwindle
  ```
- Estado y datos: el estado vive en `shell.qml` (`property var appearance`, defaults gapsIn 3, gapsOut 6, etc.). Caché en `~/.cache/oozeshell-appearance.json` (`appearanceCacheFile`, `shell.qml`). `WmAppearance` (`COMMON/WmAppearance.qml`, singleton) genera configs del WM (hypr/niri/mango) y aplica cambios live.
- Dependencias: `../COMMON` (Theme, FusedWindow, FusedPanel, PanelHeader), `../LANG`, y `WmAppearance` + `WM` para filtrar specs por WM (`specAllowed`: `gapsIn`/opacidades no aplican en niri; blur/sombra según `WM.has()`).
- Notas: los sliders filtrados por WM desaparecen (`visibleSliders`); los de sombra se atenúan si `shadowEnabled` es false. `animProfile` también se edita aquí aunque no es slider.
