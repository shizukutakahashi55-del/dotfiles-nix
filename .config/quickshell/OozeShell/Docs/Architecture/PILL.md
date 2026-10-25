# PILL — barra minimalista del modo píldora

- Qué es: la superficie que sustituye a la barra cuando `Theme.pillMode` está activo. Una `Pill` por
  monitor (`Variants` sobre `Quickshell.screens`, namespace `oozeshell-pill`) que hospeda las opciones,
  el `Dashboard`, el reloj, los controles MPRIS, el indicador de notificaciones, la taskbar, la bandeja
  del sistema y los indicadores de workspaces. Gestiona auto-hide, zona de disparo y foco de teclado.
- Flujo en tres pasos: **píldora → opciones → panel**. Clic en el reloj abre las opciones (rejilla de 4
  columnas con las secciones); elegir una abre el panel de esa sección. Cada paso reemplaza al anterior
  con la misma transición de tamaño. Volver: botón ‹ de la barra del panel o `Esc` (panel → opciones →
  píldora). Clic fuera cierra todo de una vez.
- Atajos que se saltan las opciones: clic en la píldora de música abre `mpris`, clic derecho en el reloj
  abre `calendar` y los IPC (`menu`, `audio`, `agenda`, `mpris`, `powermenu`) abren su panel directo. En
  todos los casos `Esc` regresa a las opciones.
- Archivos:
  - `Modules/Pill/Pill.qml` → barra/píldora por monitor; hospeda `PillOptions`, `Modules/Dashboard/Dashboard.qml`,
    taskbar, reloj y bandeja; administra auto-hide, foco de teclado y los tres niveles de tamaño
  - `Modules/Pill/PillOptions.qml` → paso 2: una sola fila de botones circulares con resaltado deslizante y
    la etiqueta de la opción activa debajo; teclado (`←/→`, `HJKL`, `Tab`, `1…7`, `Enter`) que emite
    `picked(sección)`; al pasar el cursor o mover la selección precarga la sección
  - `Modules/Pill/PillClock.qml` → reloj; usa el estilo de `Theme.barClockStyle` vía `COMMON/ClockFace.qml` (ver BAR.md)
  - `Modules/Pill/PillMedia.qml` → controles MPRIS compactos (lee `Services/Mpris/MprisBackend.qml`)
  - `Modules/Pill/PillNotifications.qml` → indicador y lista de notificaciones de la píldora
  - `Modules/Pill/PillTaskbar.qml` → taskbar (reexporta `Modules/Taskbar/TaskbarList.qml`)
  - `Modules/Pill/PillTray.qml` → bandeja del sistema (`Modules/Tray/TrayMenuList.qml`)
  - `Modules/Pill/PillWorkspaces.qml` / `PillWorkspacesSide.qml` → indicadores de workspaces (el lateral
    usa el namespace `oozeshell-pill-workspaces`)
- IPC: sin target propio. Se interactúa con la píldora a través de los targets que redirigen según el
  modo: `menu toggle` (abre la sección `quickaccess` del dashboard), `notify toggle` (lista de avisos de
  la píldora), `audio`, `agenda`, `mpris`, `performance` y `powermenu`. Ver SHELL.md para la
  tabla completa y DASHBOARD.md para el mapa de secciones por modo.
- Estado y datos: `COMMON/AppState.qml` (`dashboardOpen`, `dashboardScreen`, `dashboardSection`,
  `pillOptionsOpen`, `pillOptionsScreen`, `pillLayerOpen`, `pillAutoHide`, `pillHiddenNow`,
  `pillTraySync`, `trayVisible`). Ojo: las notificaciones de la píldora usan su propio
  `notifyOpen`/`notifyScreen` locales, no el centro de notificaciones de la barra.
- Dependencias: `COMMON` (AppState, WM, Theme), `Services/Lang`, `Modules/Taskbar`, `Modules/Tray`,
  `Modules/Dashboard`, `Services/Notify` y `Services/Mpris` (solo `PillMedia.qml`).
- Notas: con `pillAutoHide` la píldora se oculta y deja una zona de disparo (`triggerH`); `reserveZone`
  compensa `AppState.gapsOut`. La sección de avisos del dashboard no existe en este modo (ver
  DASHBOARD.md) precisamente porque la píldora ya trae la suya.

## Puntos a vigilar

- **Fórmula de tamaño de `surface` (`Pill.qml`)**: `width`/`height` suman tres términos (`op` opciones,
  `progress` panel, `mp` menús) y cada uno interpola hacia su destino, de modo que con `op = progress = 1`
  el resultado es exactamente el tamaño del panel. Si se añade un cuarto nivel hay que repetir ese patrón
  (término propio que reste el nivel anterior); si no, el borde salta o termina con un tamaño erróneo.
  Tocarla también afecta `pillT`, `optionsT` y `dashT`, que son las que cruzan los fundidos.
- **Quién cierra qué (`AppState`)**: `closeDashboard()` cierra panel **y** opciones, y es lo que ya llaman
  `shell.qml`, los IPC y las secciones (por ejemplo «Grabar»). `openPillOptions()` es la única vía para
  «volver un paso». Los guardas de `shell.qml` usan `pillLayerOpen`; si se vuelven a escribir con
  `dashboardOpen`, las opciones quedarían abiertas al abrir otro popup.
- **Precarga desde `PillOptions` (`onHovered` en `Pill.qml`)**: escribe `AppState.dashboardSection` con el
  panel cerrado para que la sección se cargue antes del clic. Si el panel se siente lento, conviene
  mantenerlo; si un día `dashboardSection` debe significar «última sección realmente abierta», hay que
  quitar ese handler (y el temporizador `dwell` de `PillOptions`).
- **Clic en la píldora de música (`onOpenRequested`)**: abre `mpris` directo. Para que pase por las
  opciones, cambiar a `AppState.openPillOptions(root.screenName)`.
- **Fila de opciones (`PillOptions`)**: todas las secciones van en una línea; `implicitWidth` se recalcula
  con el número de secciones (`btn`, `gap`, `padX`), así que al añadir secciones conviene revisar que el
  ancho no supere el del panel más ancho. `↑/↓` no hacen nada en la fila.
- **Pager del panel (`swipeArea` / `WheelHandler` en `Dashboard.qml`)**: el arrastre vive en el propio
  `Dashboard` (un `MouseArea` con `z: -1`, por debajo de las secciones), así que solo se activa si la
  pulsación cae en una zona libre y nunca le quita el gesto a sliders, listas o botones. Ya no hay
  `panelDrag` en `Pill.qml`: el `MouseArea` de fondo de la superficie capturaba la pulsación y el
  `DragHandler` (con `TakeOverForbidden`) no llegaba a activarse. El arrastre no da la vuelta
  (`stepClamped`); el teclado y `stepSection` sí.

- **Transición opciones ↔ panel (`surface.flow`)**: los fundidos (`pillT`, `optionsT`, `dashT`) se calculan con `flow`, una curva `InOutCubic` de 480 ms al abrir e `InOutQuad` de 260 ms al cerrar, y no con `progress` (que tiene rebote `OutBack` y cruzaba los umbrales en unos 100 ms). `progress` solo mueve la geometría. Las opciones se desvanecen en el primer 55 % y el panel entra desde el 30 %, así que se solapan.
- **Memoria en reposo**: con «Paneles bajo demanda» el `Dashboard` de la píldora no se destruye (vive dentro de `Pill.qml`, no en un `LazyPopup`); solo se descargan sus secciones. Con la opción activa ya no se precarga al pasar el cursor por la píldora (`noteHover`), y 5 s después de cerrar se llama a `gc()` (`trimTimer`; en barra, `DashboardPanel`) porque en reposo el recolector de QML no corre solo.

- **Orden al cerrar**: primero se desvanece el panel (`flow`), y solo después, con 150 ms de pausa (`PauseAnimation` en `progress` y `op`), la superficie se encoge hasta el tamaño de las opciones o de la píldora. Si la geometría encogiera a la vez, el panel se vería recortado. Al abrir es al revés: la superficie crece y el panel aparece cuando ya casi tiene su tamaño (`dashT` entre 0.45 y 0.9 de `flow`).
