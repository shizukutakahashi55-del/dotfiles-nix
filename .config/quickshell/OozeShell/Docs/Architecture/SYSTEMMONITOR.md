# SYSTEMMONITOR — ventana de aplicación con métricas del equipo (IPC `sysmon`)

- Qué es: una ventana de aplicación normal de OozeShell (`FloatingWindow`, toplevel xdg) con cuatro
  secciones de métricas: Resumen, Procesos, Discos y Red. **No** es un panel de la barra/píldora: solo
  se abre por bind o por IPC. Convive con la sección «Rendimiento» del Dashboard (son cosas distintas,
  se pueden tener las dos abiertas).
- Archivos:
  - `Modules/SystemMonitor/SystemMonitorWindow.qml` → la ventana: `visible: AppState.sysMonOpen`,
    título `OozeShell — System Monitor`, tamaño `980×640` escalado por `Theme.windowScale` (mínimo
    `760×480`), pantalla `AppState.sysMonScreen`; cabecera con el selector de sección y el estado del
    backend
  - `Modules/SystemMonitor/OverviewSection.qml` → CPU (uso, frecuencia, núcleos, temperatura), RAM y GPU
  - `Modules/SystemMonitor/ProcessesSection.qml` → lista de procesos (PID, usuario, CPU %, memoria,
    actividad) con orden por CPU/memoria/PID/nombre (también desde la cabecera de columna), barras de CPU y memoria,
    acción de matar proceso en dos pasos y selector de modo de CPU: `Total` (0–100 % del equipo, coherente con
    el Resumen) o `Por núcleo` (100 % = un núcleo completo, como `top`)
  - `Modules/SystemMonitor/DisksSection.qml` → discos (uso y velocidad de lectura/escritura)
  - `Modules/SystemMonitor/NetworkSection.qml` → red (bajada, subida, interfaz)
  - `Modules/SystemMonitor/MonitorCard.qml` / `MonitorMetric.qml` → tarjeta y métrica reutilizables
  - `Modules/SystemMonitor/SegmentedControl.qml` → selector segmentado con indicador deslizante (secciones,
    orden y modo de CPU); `Modules/SystemMonitor/MonitorChip.qml` → etiqueta compacta
- IPC (`Core/Ipc/SystemMonitorIpc.qml`, target `sysmon`):

  | Función | Efecto |
  |---|---|
  | `open <sección>` | abre en una sección (`overview`, `processes`, `disks`, `network`); con la sección vacía usa `overview` |
  | `close` | cierra |
  | `toggle` | abre/cierra **sin argumentos**, en la sección actual (`overview` de fábrica) |
  | `section <nombre>` | cambia de sección si está abierta |
  | `isOpen` | `true`/`false` |
  | `backend` | `native/qml` (métricas) y `native/ps` (procesos) según lo compilado |

  ```sh
  oozeshell sysmon toggle
  oozeshell sysmon open processes
  oozeshell sysmon close
  quickshell ipc -c OozeShell call -- sysmon backend
  ```

  Bind de ejemplo (cada WM tiene su sintaxis): `bind = SUPER, M, exec, oozeshell sysmon toggle`
- Estado y datos: `AppState` (`COMMON/AppState.qml`): `sysMonOpen`, `sysMonScreen`, `sysMonSection`
  (por defecto `overview`) y `openSystemMonitor/closeSystemMonitor/toggleSystemMonitor`.
- Métricas: `Backends/SystemMonitor.qml` + `Backends/ProcessList.qml` (ver CORE.md). La ventana los
  registra por referencia mientras está visible (`setWanted("app", …)`) y `ProcessList` solo en la
  sección de procesos: **cerrada no cuesta nada**. Mientras está abierta muestrea cada `1000 ms`
  (métricas) y `1500 ms` (procesos).
- Dependencias: `COMMON` (Theme, AppState, OozeIcons), `Services/Lang`, `Backends`.
- Notas — flotar la ventana: al ser un toplevel xdg, quien decide si flota es el compositor. El
  `app-id`/clase de la ventana es **`org.quickshell`** (comprobado con `hyprctl clients`), el mismo de
  cualquier ventana de Quickshell. Sin regla, se abre en mosaico en Hyprland, niri y Mango; con una
  regla queda flotante y con su tamaño.

  En Hyprland la configuración es Lua (`~/.config/hypr/hyprland.lua` + los módulos que `require()`), y
  las reglas se declaran con `hl.window_rule`:

  ```lua
  -- ~/.config/hypr/modules/rules/windowrules.lua
  hl.window_rule({
      name  = "oozeshell-sysmon",
      match = { class = "^(org.quickshell)$" },
      float = true,
      size  = {980, 640},
  })
  ```

  ```kdl
  // niri (config.kdl o un módulo incluido)
  window-rule { match app-id="org.quickshell"; open-floating true; }
  ```

  ```ini
  # mango (~/.config/mango/conf/rules.conf)
  window_rule=is_floating:1,width:980,height:640,app_id:org.quickshell
  ```

  La regla matchea **todas** las ventanas xdg de Quickshell. Agreaga tittle para que sea un match fijo.