# DASHBOARD — panel central con secciones conmutables (barra y píldora)

- Qué es: contenedor único (`Modules/Dashboard/Dashboard.qml`) con una cabecera de iconos y **una
  sección visible a la vez** (energía, reproductor, rendimiento, audio, avisos, enfoque, calendario,
  accesos rápidos y —si el WM no trae vista general nativa— workspaces). Lo usan los dos modos:
  - **Barra**: `Modules/Dashboard/DashboardPanel.qml` (`FusedWindow` + `FusedPanel`, namespace
    `oozeshell-dashboard`); solo activo en modo barra.
  - **Píldora**: `Modules/Pill/Pill.qml` (el mismo `Dashboard` dentro del cuerpo de la píldora, con
    `backMode: true`: en lugar de la fila de iconos lleva `DashboardBack` y el acceso entre secciones es
    la fila de `Modules/Pill/PillOptions.qml`).
  Ambos comparten estado (`AppState.dashboardOpen` / `dashboardScreen` / `dashboardSection`) y el
  mismo `Dashboard.qml`. El antiguo `Modules/Menu/Menu.qml` ya no existe: `Modules/Menu/` conserva solo
  los componentes compartidos `Sparkline.qml` y `SystemStats.qml`.
- Archivos:
  - `Modules/Dashboard/Dashboard.qml` → contenedor: orden de secciones, dos ranuras (`slotA`/`slotB`)
    con transición deslizante, precarga y reenvío de teclas (`handleKey` delega en la sección)
  - `Modules/Dashboard/DashboardHeader.qml` → cabecera estilo launcher: fila de iconos y, **solo en el
    item activo**, su etiqueta (ver «Medidas»). Solo se muestra en barra
  - `Modules/Dashboard/DashboardPager.qml` → pager de la cabecera de la píldora (puntos, indicador
    deslizante, pulsar/arrastrar/rueda); lo usa `DashboardBack`
  - `Modules/Dashboard/DashboardBack.qml` → cabecera de la píldora (`backMode`): botón ‹ , icono y título
    de la sección y la pista `Esc`; emite `backRequested`
  - `Modules/Dashboard/DashboardSections.qml` → lista única de secciones (`all`, `forBar`, `forPill`);
    la usan la cabecera, `DashboardBack` y `PillOptions`
  - `Modules/Dashboard/DashboardTile.qml` → ficha compacta (icono, título y estado) usada por las opciones
    de la píldora y por Ajustes en modo píldora
  - `Modules/Dashboard/DashboardNav.qml` → movimiento por cuadrícula con el teclado (ver «Teclado»)
  - `Modules/Dashboard/DashboardPanel.qml` → host de barra (`notifsShown`, montaje sobre `FusedWindow`)
  - `Modules/Dashboard/DashboardPower.qml` → energía/sesión
  - `Modules/Dashboard/DashboardMpris.qml` → reproductor (reutiliza `MPRIS`)
  - `Modules/Dashboard/DashboardPerformance.qml` → CPU/RAM/GPU (reutiliza `Backends/SystemMonitor` y
    `Modules/Menu/Sparkline.qml`)
  - `Modules/Dashboard/DashboardAudio.qml` → audio (reutiliza `Services/Audio`)
  - `Modules/Dashboard/DashboardNotifications.qml` → centro de avisos (solo barra)
  - `Modules/Dashboard/DashboardFocus.qml` (alto reducido; publica `minHeight`, que `Dashboard.sectionMinH` usa en lugar de `minContentH` en píldora) → página Enfoque: `DashboardPomodoro.qml` +
    `DashboardTodo.qml` en una sola fila
  - `Modules/Dashboard/DashboardCalendar.qml` → calendario/agenda (reutiliza `Services/Agenda`)
  - `Modules/Dashboard/DashboardQuickAccess.qml` → accesos rápidos (red, bluetooth, brillo, ajustes…)
  - `Modules/Dashboard/DashboardPomodoro.qml`, `DashboardTodo.qml` → piezas de Enfoque
- Secciones por modo (`DashboardHeader.allItems` + `barExcluded` / `pillExcluded`):
  - **Barra** (`barExcluded = ["power", "mpris"]`, 6 items): `performance`, `audio`,
    `notifs`, `focus`, `calendar`, `quickaccess`.
  - **Píldora** (`pillExcluded = ["notifs"]`, 7 items): `power`, `mpris`, `performance`, `audio`,
    `focus`, `calendar`, `quickaccess`. La sección de avisos no se muestra porque la
    píldora ya tiene su propia lista (`Modules/Pill/PillNotifications.qml`).
  - Las exclusiones viven en `DashboardSections.qml`. Una sección nueva se registra en `all`, en
    `Dashboard.urlFor` y con su clave `dashboardSectionX` en `LangEs`/`LangEn`.
- IPC: sin target propio. Se controla a través de `AppState` y de los targets que **redirigen** al
  dashboard: `menu toggle` (accesos rápidos), `audio` (sección Audio), `agenda` y clic derecho del reloj
  (sección Calendario), `notify` (avisos, solo barra), `performance`, `mpris` y `powermenu` (solo píldora
  para los dos últimos).
- Estado y datos: `COMMON/AppState.qml` (`dashboardOpen`, `dashboardScreen`, `dashboardSection` y
  `openDashboard/closeDashboard/toggleDashboard`). `Dashboard.section` es derivada: si
  `AppState.dashboardSection` no está en el modo actual se usa la primera del modo, y `AppState` se
  normaliza al abrir. `DashboardPanel` publica `notifsShown` en `NotificationsBackend.centerOpen` (solo
  barra) y lo resetea al destruirse. `DashboardTodo` fija `todayKey` al crearse.
- Dependencias: `COMMON`, `Services/Lang`, `Modules/Menu` (Sparkline/SystemStats) y, por sección,
  `Services/Notify`, `Services/Agenda`, `Services/Audio`, `Services/Mpris` y `Backends`.
- Notas: los hosts reaccionan a las señales `requestNetwork`, `requestBluetooth`, `requestAppearance`,
  `requestWalls` y `requestAdvancedSettings` que emite el dashboard (accesos rápidos) para abrir el popup
  o la página de ajustes que toque en cada modo.

## Teclado

El dashboard se maneja entero con el teclado, en modo barra y en modo píldora. En barra, `DashboardPanel` reenvía las teclas de `FusedWindow` a `Dashboard.handleKey`; en píldora lo hace el `keyCatcher` de `Pill.qml`. `Esc` cierra.

### Cómo se reparte cada tecla

`Dashboard.handleKey` decide en tres pasos, en este orden:

1. **Atajos globales**, que funcionan en cualquier sección (incluso en las que usan las flechas, como vista general): `Ctrl+←/→` o `Ctrl+H/L`, `PageUp/PageDown` y `Alt+1…9`.
2. **La sección activa** (`handleKey` de su `.qml`). Si devuelve `true`, la tecla se consume.
3. **Respaldo**: lo que la sección no use cambia de sección: `←/→`, `H/L`, `Tab`/`Shift+Tab` y los números `1…9`.

Por eso en las cuadrículas y pestañas, al llegar al borde `←/→` pasa a la sección vecina sin soltar la tecla.

### En modo píldora (`backMode`)

No hay fila de iconos, así que el respaldo de la sección vecina (`←/→`, `H/L`, `Tab`, `1…9`) queda
desactivado y esas teclas pasan solo a la sección activa. Siguen los globales (`Ctrl+←/→`, `PageUp/PageDown`,
`Alt+1…9`) y `Esc` vuelve a las opciones en lugar de cerrar. En las opciones: flechas/`HJKL` y `Tab` mueven,
`Enter`/`Espacio` abre, `1…7` abre directo y `Esc` cierra.

### Pager (deslizar entre paneles)

En barra y en píldora el panel se pagina arrastrando horizontalmente con el ratón (o dos dedos en el
touchpad): el panel acompaña al cursor con resistencia y, al soltar pasados `swipeThreshold` px, pasa
al siguiente o anterior con la transición deslizante. En los extremos no da la vuelta (el teclado, con
`Ctrl+←/→`, `Ctrl+H/L` y `PageUp/PageDown`, sí). El arrastre solo cuenta si empieza en una zona libre:
no roba el gesto a sliders, barras de progreso ni listas.

`DashboardPager.qml` (cabecera de la píldora) es la pista de puntos con un indicador que se desliza: se
puede pulsar, arrastrar por encima para recorrer las páginas o usar la rueda.

### Globales

| Tecla | Acción |
|---|---|
| `Ctrl+←` / `Ctrl+→` (o `Ctrl+H` / `Ctrl+L`) | Sección anterior / siguiente |
| `PageUp` / `PageDown` | Sección anterior / siguiente |
| `Alt+1…9` | Ir a la sección número N |
| `←` `→` `H` `L` `Tab` `Shift+Tab` `1…9` | Lo mismo, cuando la sección no usa la tecla |
| `Esc` | Cerrar |

### Por sección

| Sección | Teclas |
|---|---|
| Energía | `←↑↓→` (o `HJKL`) mueven la selección; `Enter`/`Espacio` arma la acción y un segundo `Enter` la ejecuta (los 3 s de confirmación de siempre) |
| Reproductor | `Espacio`/`Enter` pausa o reanuda; `N` o `Shift+→` siguiente; `P` o `Shift+←` anterior; `.` y `,` adelantan o atrasan 5 s; `↑`/`↓` cambian de reproductor |
| Rendimiento | sin acciones propias |
| Audio | `←`/`→` cambian de pestaña (salida, entrada, mezclador); `↑`/`↓` suben o bajan el volumen (5 %, 10 % con `Shift`); `M` o `Espacio` silencia |
| Avisos | `C`, `Supr` o `Retroceso` limpian todo; `D` activa o desactiva No molestar |
| Enfoque | `Espacio`/`Enter` inicia o pausa el pomodoro; `S` salta de fase; `R` reinicia; `A`, `N` o `/` enfocan el campo de tareas (`Esc` lo suelta) |
| Calendario | `↑`/`↓` mes anterior / siguiente; `T`, `Inicio` o `Espacio` vuelven a hoy |
| Accesos rápidos | `←↑↓→` (o `HJKL`) mueven la selección; `Enter`/`Espacio` activa (4 columnas en píldora, 2 en barra) |

### Selección visible

Energía y Accesos rápidos usan `kbd` (la selección solo se ve tras pulsar una tecla) y `sel` (índice marcado). Mover el ratón apaga `kbd`, así el resaltado del teclado y el del ratón nunca se mezclan. La primera pulsación de `Enter` solo revela la selección, para no ejecutar una acción a ciegas.

### Cómo añadir teclado a una sección

Definir `function handleKey(key, modifiers)` en la sección y devolver `true` solo si la tecla se usó. Para cuadrículas, instanciar `DashboardNav { id: nav }` y usar `nav.move(sel, cantidad, columnas, tecla)`, que devuelve el nuevo índice o `-1` si se llegó al borde (devolver `false` en ese caso deja que `←/→` cambien de sección).

