# BAR — Barra por pantalla + marco y esquinas

- Qué es: `Variants` por pantalla con fondo blur, módulos izquierda/centro/derecha y marco continuo (Border + FrameCorner). Se oculta en fullscreen o durante cambio de wallpaper; vacía (`[]`) en `pillMode`.
- Archivos:
  - `Modules/Bar/Bar.qml` → `Variants { model: pillMode ? [] : screens }`: `PanelWindow` fondo, `cornersTop`/`cornersBottom`, `Border`, `CenterModules`/`LeftModules`/`RightModules`; señales `*ButtonClicked` hacia `shell.qml`.
  - `Modules/Bar/Border.qml` → 4 `PanelWindow` rectos (top/bottom/left/right, namespaces `oozeshell-frame-*`); solo visibles con marco curvo activo y lado sin barra.
  - `Modules/Bar/components/FrameCorner.qml` → esquina deformada (Shape); única parte curva del marco.
  - `Modules/Bar/LEFT/LeftModules.qml`, `Modules/Bar/CENTER/CenterModules.qml`, `Modules/Bar/RIGHT/RightModules.qml` → las tres islas. Solo contienen geometría (ventana, píldora, tooltip, rectángulo de isla); qué módulos muestran lo decide el picker.
  - `Modules/Bar/components/BarHost.qml` → base común de las tres islas: señales de botones, estado de popups, tooltips, menús de bandeja/taskbar, publicación en `IslandState`.
  - `Modules/Bar/components/BarSectionRow.qml` → contenido de una isla: lee `Theme.barModulesOf(side)`, instancia los módulos en orden, pone separadores entre módulos visibles y expone `occupied` (hay algo visible).
  - `Modules/Bar/components/BarRevealZone.qml` → zona de disparo (ns `oozeshell-bar-reveal`) que aparece cuando la barra está oculta; al pasar el ratón o clic pide el `peek`.
  - `Modules/Bar/modules/` → un archivo por módulo (`PowerModule`, `LangModule`, `MprisModule`, `NotificationsModule`, `WorkspacesModule`, `ClockModule`, `AudioModule`, `BatteryModule`, `PrivacyModule`, `TaskbarModule`, `TrayModule`, `MenuModule`) y `BarPillButton`. Cada uno recibe `host` (la isla) y expone `shown`.
  - `Modules/Bar/CENTER/CALENDAR/CalendarDrop.qml` → calendario del reloj; siempre se dibuja en la ventana de CENTER, aunque el reloj esté en otra isla (estado en `COMMON/BarCalendar.qml`).
- IPC (Core/Ipc/BarIpc.qml target `bar`, Core/Ipc/CornersIpc.qml target `corners`):

  | target | función | efecto |
  |---|---|---|
  | `bar` | `position <p>` / `togglePosition` | `top\|bottom\|left\|right` / rota al opuesto |
  | `bar` | `floating <b>` / `toggleFloating` | barra flotante sí/no |
  | `bar` | `floatWindows <b>` / `toggleFloatWindows` | ventanas, paneles y tooltips flotantes (sin curvas de unión), con o sin Cristal; el modo performance (`shellPerf`) los activa mientras esté encendido, sin tocar este ajuste |
  | `bar` | `windowAnim <estilo>` / `cycleWindowAnim` | `spring\|smooth\|zoom\|pop\|slide\|fade`: animación de las ventanas flotantes (Cristal y flotantes) |
  | `bar` | `islands <b>` / `toggleIslands` | modo islas sí/no |
  | `bar` | `hidden <b>` / `toggleHidden` / `hiddenFrame <b>` | ocultar barra / mantener marcos al ocultar |
  | `bar` | `revealMode <hover\|click>` / `peek` | cómo reaparece la barra oculta / mostrarla temporalmente |
  | `bar` | `pill <b>` / `togglePill` | modo pill (sin barra clásica) sí/no |
  | `bar` | `templateSave <nombre>` / `templateLoad <nombre>` / `templateDelete <nombre>` / `templates` | plantillas de barra: guardar / aplicar / borrar / listar (builtin + guardadas) |
  | `bar` | `get` | JSON `{position, floating, islands, pill, floatWindows, windowAnim, hidden, hiddenFrame, revealMode}` |
  | `corners` | `toggle` / `set <b>` / `get` | esquinas de pantalla sí/no |

  ```bash
  quickshell ipc -p .../shell.qml call -- bar position top
  quickshell ipc -p .../shell.qml call -- bar toggleFloating
  quickshell ipc -p .../shell.qml call -- bar get
  quickshell ipc -p .../shell.qml call -- corners toggle
  ```
- Estado y datos: sin singleton/JSON propios; todo vive en `Theme` (`COMMON/Theme.qml`): `barPosition`, `barFloatingPref`, `islandsPref`, `pillModePref` (+ derivados `barVertical`, `barAtBottom`, `islandsMode`). Persistidos en `~/.config/oozeshell/ui.json`. `screenCorners` vive en `shell.qml` (`root.screenCorners`).
- Dependencias: `COMMON` (Theme, SkinRect, GlassRegion, FullscreenState), `Services/Walls` (WallsFrameFlare), `Services/Lang`, `Services/Mpris`. Los botones delegan a popups de `shell.qml` vía señales.
- Notas: `framArmsActive` requiere marco on + curvo + no separado + no reconstruyendo; los brazos (`armTop/Bottom/Left/Right`) reservan espacio junto a esquinas. `Theme.barRebuilding` oculta la barra durante cambios de layout. El módulo de audio y el clic derecho del reloj abren el Dashboard (secciones Audio y Calendario) en lugar de popups propios; el mini-calendario en hover del reloj (`Modules/Bar/CENTER/CALENDAR/CalendarDrop.qml`) se conserva. La caja de componentes compartidos `Modules/Menu/` solo contiene `Sparkline.qml` y `SystemStats.qml`.

## Picker de módulos (Ajustes → Barra → Módulos)

- Aplica a barra normal, flotante, islas y vertical. No aplica a Píldora.
- Datos: `Theme.barLayoutPref` = `{left: [...], center: [...], right: [...]}` con ids de módulo; se guarda en `ui.json` (`barLayout`). API: `barModulesOf(side)`, `barSideOf(id)`, `placeBarModule(id, side, index)`, `nudgeBarModule(id, delta)`, `resetBarLayout()`. En barra vertical left = arriba, right = abajo.
- Un módulo está en una sola isla a la vez; puede quedar fuera de la barra.
- Isla vacía (o con módulos que no se ven, p. ej. privacidad sin uso): `occupied = false` → su ventana se oculta y se borra de `IslandState`.
  - Barra normal / vertical: el fondo de la barra sigue completo.
  - Islas: la isla vacía desaparece.
  - Flotante: el fondo (`barBg` en `Bar.qml`) se encoge hacia las islas con contenido; si izquierda y derecha tienen contenido queda a todo el ancho, aunque el centro esté vacío.
- Los popups (audio, menú, mpris, energía, notificaciones, agenda) salen del lado donde esté su módulo (`Theme.popupAlign` / `Theme.popupIsland`); en Píldora usan su alineación original.

## Ocultar barra

- `Theme.barHiddenPref` (efectivo: `Theme.barHidden`, nunca en Píldora ni con Waybar). Persistido en `ui.json` (`barHidden`, `barHiddenFrame`).
- Las ventanas de la barra NO se destruyen: quedan mapeadas pero vacías (máscara de entrada vacía, fondo transparente, `exclusionMode: Ignore`), así que no se reserva espacio y al volver a mostrarla no hay que recrear ventanas. `BarHost.shown = occupied && !barHidden` gobierna las píldoras. Flotante e islas se desactivan mientras está oculta.
- Marcos (`barHiddenFramePref`, por defecto ON): `Theme.frameBarSide` pasa a `""`, así `Border.qml` dibuja las 4 franjas y `Bar.qml` pone brazos y esquinas en los 4 lados; el lado de la antigua barra queda como un lado más del marco. `Theme.barThickness` pasa a valer el grosor de la franja (o 0 sin marco) para que popups y OSD cuelguen debajo de ella sin solaparse. OFF: `Theme.frameOn` es falso mientras está oculta.

## Capa del fondo de la barra (barra normal y flotante)

- Estructura: el fondo (`barPanel` en `Bar.qml`) es una ventana aparte de los módulos (`LeftModules`, `CenterModules`, `RightModules`).
- Capas: fondo en `Top` y módulos en `Overlay` en todos los WM (ver COMMON.md, "Orden de capas"). No se pone el fondo en la misma capa que los módulos porque, al recrear la barra, el fondo podía mapearse después y tapar los módulos.
- Durante fullscreen o cambio de wallpaper el fondo se oculta con `screenRoot.suppressed` (opacidad 0 y máscara vacía).
- Modo cristal: el fondo sigue siendo `barPanel` con su `GlassRegion`; los módulos usan `Theme.islandBg` transparente en barra normal.

## Marco en modo cristal

- `Theme.frameOn` es falso con `Theme.glassMode`, por diseño. El marco se arma con cuatro franjas (`Border.qml`) y cuatro esquinas (`FrameCorner.qml`, ventanas aparte) que se solapan en los brazos. Con color opaco no se nota; con transparencia el solape duplica la opacidad y deja costuras visibles, y el blur no tiene una región con la forma del marco.
- Para soportarlo haría falta dibujar el marco como una sola forma por pantalla (rectángulo exterior menos rectángulo interior redondeado) con relleno `Theme.glassBg` y una región de blur propia. No está hecho.
