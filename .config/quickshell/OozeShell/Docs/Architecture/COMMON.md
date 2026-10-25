# COMMON — Singletons y widgets compartidos de todo el shell

- Qué es: biblioteca base sin UI propia: singletons de estado global (tema, WM, utilidades) + componentes visuales reutilizados por todos los módulos (`FusedWindow`, `SkinRect`, `Pixel*`, etc.).
- Archivos (rol en una línea):
  - `Theme.qml` → singleton: colores/fuentes/radii, `barPosition`/`barFloating`/`islands`/`pill`, niveles UI, `performanceMode`, persistencia `ui.toml` + `colors.json`.
  - `WM.qml` → singleton: abstracción hyprland/niri/mango (`wm`, `has()`, overview nativo); prefs en `~/.config/oozeshell`.
  - `WmAppearance.qml` → singleton: aplica `appearance` al WM (live + autogen por WM).
  - `AppState.qml` → singleton: dashboards `pillMode` (sección visible por monitor).
  - `HyprState.qml` / `HyprDispatch.qml` → estado hyprland / envío de dispatches.
  - `NiriState.qml` / `MangoIpc.qml` → estado niri / IPC de mango (`mmsg`).
  - `IslandState.qml` / `FullscreenState.qml` → qué isla está abierta / qué pantalla está en fullscreen.
  - `ModeRuntime.qml` → modo runtime actual; `Motion.qml` → curvas/duraciones de animación.
  - `KeyboardLayout.qml` → layout actual + `next()` (IPC `keyboardlayout`).
  - `UserProfile.qml` → avatar/nombre; guarda `avatar-*` en `~/.config/oozeshell`.
  - `AudioLevels.qml` / `Fuzzy.qml` / `OozeIcons.qml` → niveles de audio para viz / búsqueda difusa / set de iconos.
  - `FusedWindow.qml` / `FusedPanel.qml` / `FusedTip.qml` → ventana fusionada al borde + panel animado + tooltip.
  - `SkinRect.qml` / `NotchRect.qml` / `GlassRegion.qml` → rectángulo con borde interior / con muesca / región de blur.
  - `CozyBox.qml` / `CozyButton.qml` / `PanelHeader.qml` / `SectionLabel.qml` → contenedores y cabeceras estilo cozy.
  - `PixelBar.qml` / `PixelRing.qml` / `PixelSteps.qml` / `PixelLevels.qml` → widgets pixel-art; `ChartGrid.qml` / `SpectrumBars.qml` → gráficas.
  - `BarFlow.qml` / `BarToggle.qml` / `WorkspaceDots.qml` / `WorkspaceChip.qml` → layout de barra, toggle, workspaces.
  - `BarCalendar.qml` → singleton: estado del calendario que cuelga del reloj de la barra (pantalla, lado, ancla).
  - `AppIcon.qml` / `Avatar.qml` / `ConfirmDialog.qml` / `LazyPopup.qml` → icono de app, avatar, diálogo, popup perezoso.
- IPC: ninguna (módulo sin `IpcHandler`; `Core/Ipc/KeyboardLayoutIpc.qml` (`keyboardlayout next`) y `Core/Ipc/ThemeIpc.qml` / `Core/Ipc/BarIpc.qml` (`theme` / `bar`) llaman a estos singletons).
- Estado y datos: 18 singletons (`qmldir`: Theme, AppState, IslandState, BarCalendar, FullscreenState, KeyboardLayout, UserProfile, HyprDispatch, Fuzzy, AudioLevels, WM, MangoIpc, HyprState, NiriState, WmAppearance, Motion, OozeIcons, ModeRuntime). Rutas exactas: `~/.config/oozeshell/ui.toml` (+ `prefsDir` en Theme/WM), `~/.cache/oozeshell/colors.json` (Theme), `~/.config/oozeshell/avatar-*` (UserProfile).
- Dependencias: solo QtQuick/Quickshell/Quickshell.Io; ningún `import ../X`. Es la base: todos los módulos importan `COMMON` (es la única carpeta que importan todos), nunca al revés. Las rutas de las dependencias se escriben desde la raíz del proyecto.
- Notas: no añadir lógica de módulo aquí; COMMON es genérico. `Theme.animDuration()` devuelve 0 en modo performance (corta todas las animaciones). Con `shellPerf` (performance activo y alcance `both` u `shell`) `Theme.floatWindows` se fuerza a verdadero mientras dure, así los paneles dejan de fusionarse con la barra; la preferencia guardada (`floatWindowsPref`) no cambia y vuelve a mandar al apagarlo. En Islas o Píldora sin Cristal no se fuerza: ahí las ventanas siguen naciendo de su isla. `GlassRegion` + `BackgroundEffect.blurRegion` es el patrón de blur en barra/paneles.

## Orden de capas: barra, islas y popups

- Regla única para todos los WM (`COMMON/WM.qml`):
  - `Bottom`: reservado a widgets de escritorio y fondo animado.
  - `Top`: fondo de la barra (`barBgLayer`, namespace `quickshell-bar-background`) y popups en modo islas/píldora (`FusedWindow.onIslands`).
  - `Overlay`: módulos de la barra, islas, píldora, marco y esquinas (`islandLayer`), además de OSD, portapapeles, diálogos, toasts y popups fuera del modo islas.
- Por qué así: dentro de una misma capa el orden lo da el orden de mapeo, y se rompe al recrear ventanas (salir del modo píldora, cambiar de modo cristal). Poner cada pieza en una capa distinta fija el orden sin depender de eso: el fondo siempre queda debajo de los módulos y las islas siempre sobre los popups que nacen de ellas.
- Por qué el fondo no va en `Bottom`: las ventanas se deslizan por encima de esa capa al cambiar de workspace en niri y el fondo desaparecía un momento mientras los módulos seguían visibles.
- Fullscreen: los módulos y el fondo se ocultan con `FullscreenState` (`suppressed`). En niri esa detección se deduce del tamaño de la ventana activa; si falla, las islas quedan sobre el fullscreen porque `Overlay` no lo cubre.
- Si un popup tapa una isla: revisar que su `FusedWindow` esté en modo islas (`onIslands`, no `floatWindows` ni fullscreen).

- Sistema Material: `MdShapes`, `MdShape`, `MdCover`, `MdWavy`, `MdWavyRing`, `MdIconButton`, `MdListItem`, `MdTokens` (ver MATERIAL.md).
- Paneles bajo demanda (`Theme.lazyPanels`, Ajustes avanzados → Interfaz → Rendimiento, apagado por defecto): `LazyPopup` tiene `lazy` (si es `false` el panel queda montado siempre, como antes) y `available` (condición de modo, p. ej. `ModeRuntime.barActive`). Con la opción activa se montan al abrir y se destruyen tras `grace` ms el popup de música (`Mpris`), `PowerMenu` y `BarSettings`. Los demás popups ya eran perezosos de forma fija. Quedan siempre montados a propósito: `DashboardPanel` (el más usado; construirlo en cada apertura se notaría), `Launcher` (indexa apps y debe abrir al instante), `ClipboardHistory` (se abre por llamada directa), `Walls` (superficie de fondo en vivo referenciada por el estado del shell), `Notify`/`NotifToasts`, `Dock`, los OSD y `LockScreen` (superficies persistentes).
