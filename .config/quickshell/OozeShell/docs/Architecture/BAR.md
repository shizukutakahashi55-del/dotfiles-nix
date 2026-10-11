# BAR — Barra por pantalla + marco y esquinas

- Qué es: `Variants` por pantalla con fondo blur, módulos izquierda/centro/derecha y marco continuo (Border + FrameCorner). Se oculta en fullscreen o durante cambio de wallpaper; vacía (`[]`) en `pillMode`.
- Archivos:
  - `BAR/Bar.qml` → `Variants { model: pillMode ? [] : screens }`: `PanelWindow` fondo, `cornersTop`/`cornersBottom`, `Border`, `CenterModules`/`LeftModules`/`RightModules`; señales `*ButtonClicked` hacia `shell.qml`.
  - `BAR/Border.qml` → 4 `PanelWindow` rectos (top/bottom/left/right, namespaces `oozeshell-frame-*`); solo visibles con marco curvo activo y lado sin barra.
  - `BAR/components/FrameCorner.qml` → esquina deformada (Shape); única parte curva del marco.
  - `BAR/LEFT/LeftModules.qml` → lado izquierdo (MPRIS, power entre otros).
  - `BAR/CENTER/CenterModules.qml` → centro (reloj → agenda con clic derecho, notificaciones, overview) + `CALENDAR/`.
  - `BAR/RIGHT/RightModules.qml` → lado derecho (audio, menú, tray, etc.).
- IPC:

  | target | función | efecto |
  |---|---|---|
  | `bar` | `position <p>` / `togglePosition` | `top\|bottom\|left\|right` / rota al opuesto |
  | `bar` | `floating <b>` / `toggleFloating` | barra flotante sí/no |
  | `bar` | `islands <b>` / `toggleIslands` | modo islas sí/no |
  | `bar` | `pill <b>` / `togglePill` | modo pill (sin barra clásica) sí/no |
  | `bar` | `get` | JSON `{position, floating, islands, pill}` |
  | `corners` | `toggle` / `set <b>` / `get` | esquinas de pantalla sí/no |

  ```bash
  quickshell ipc -p .../shell.qml call -- bar position top
  quickshell ipc -p .../shell.qml call -- bar toggleFloating
  quickshell ipc -p .../shell.qml call -- bar get
  quickshell ipc -p .../shell.qml call -- corners toggle
  ```
- Estado y datos: sin singleton/JSON propios; todo vive en `Theme` (`COMMON/Theme.qml`): `barPosition`, `barFloatingPref`, `islandsPref`, `pillModePref` (+ derivados `barVertical`, `barAtBottom`, `islandsMode`). Persistidos en `~/.config/oozeshell/ui.json`. `screenCorners` vive en `shell.qml` (`root.screenCorners`).
- Dependencias: `../COMMON` (Theme, SkinRect, GlassRegion, FullscreenState), `../WALLS` (WallsFrameFlare), `../LANG`, `../MPRIS`. Los botones delegan a popups de `shell.qml` vía señales.
- Notas: `framArmsActive` requiere marco on + curvo + no separado + no reconstruyendo; los brazos (`armTop/Bottom/Left/Right`) reservan espacio junto a esquinas. `Theme.barRebuilding` oculta la barra durante cambios de layout.
