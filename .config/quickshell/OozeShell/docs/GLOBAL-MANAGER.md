# Global-Manager — progreso y siguientes pasos

Capa común de WM/distro: `COMMON/WM.qml`. Selección en `~/.config/oozeshell/wm.json`
(`wm`, `distro`, `pkgHelper`; "auto" = detectar). La shell habla con `WM.*` y `WmAppearance.*`,
nunca con `hyprctl` / `mmsg` / `niri msg` directo (salvo lo listado en "Pendientes").

> Nada de esto se ha podido ejecutar en este entorno (no hay Quickshell ni qmllint):
> solo se comprobó que llaves, paréntesis y corchetes balanceen y que no haya funciones duplicadas.
> Falta probarlo en tus sesiones reales y pasar los errores de `quickshell -c OozeShell`.

## Arquitectura

| Archivo | Rol |
|---|---|
| `COMMON/WM.qml` | API única: monitores, ventanas, workspaces, fullscreen, teclado, acciones, capacidades |
| `COMMON/HyprState.qml` | Backend Hyprland (único que importa `Quickshell.Hyprland`) |
| `COMMON/MangoIpc.qml` | Backend Mango (`mmsg watch`) |
| `COMMON/NiriState.qml` | Backend Niri (`niri msg --json event-stream` + `outputs`) |
| `COMMON/WmAppearance.qml` | Apariencia por WM: aplicar en vivo, archivos autogen, layouts |
| `SETTINGS/pages/GlobalManagerPage.qml` | Ajustes avanzados > Global-Manager |

Los backends son singletons perezosos: solo se crea el del WM efectivo.

Formas comunes (iguales en los tres backends):
- monitor: `{ name, id, x, y, width, height, scale, transform, focused, activeWorkspaceId }`
- ventana: `{ address, class, initialClass, title, workspace:{id,name}, monitor (NOMBRE), at, size, floating, focusHistoryID }`
- workspace: `{ id, name, active, urgent, monitor, activate() }`

## Progreso

- [x] **Fase 1** — `WM.qml`, página Global-Manager, selección persistente, `WM.has()`, acciones básicas, traducciones.
- [x] **Fase 2** — estado unificado (Overview, Dashboard, Launcher, Mpris, barra, píldora, fullscreen, teclado).
- [x] **Ajustes de workspaces** (esta ronda)
  - Números 1–10 y más: caja dibujada (`WorkspaceChip.boxText`) en vez de glifos Nerd Font que solo llegan al 9.
    CoOzey sigue con números reales; el activo ya no usa ❄ (número resaltado); los especiales de Hyprland con ✦.
  - Niri: la barra y la píldora muestran solo el workspace actual (`WM.barWorkspacesFor`).
  - Niri: el botón de workspaces del Dashboard cierra el Dashboard y abre el overview nativo
    (`niri msg action toggle-overview`). En Hyprland y Mango sigue abriendo la vista propia.
- [x] **Fase 3** — apariencia y autogen por WM.
  - `shell.qml` ya no tiene `hyprctl`: el estado, el cache JSON y el IPC siguen ahí; lo que depende del WM
    pasó a `WmAppearance`.
  - Panel Appearance: layouts, sliders y toggles según el WM (`WM.has(...)`); toggle "Blur optimizado" solo en Mango.
  - Reboot/apagar sin `hyprshutdown` fuera de Hyprland (va directo `systemctl`).
  - La categoría de monitores de Hyprland se oculta fuera de Hyprland (ya estaba, fase 1).
- [x] **Fase 4** — PackageSearch unificado (`PackageSearch/PackageSearch.qml`, reemplaza a `NixSearch`).
  - Backend por `WM.packageBackend`: `nix-search` (nixpkgs) | `paru` | `yay` (repos + AUR) | `pacman` (repos).
  - Arch: `<tool> --color never -Ss -- términos` (LC_ALL=C), máx. 60 resultados; insignia ✔ instalado / AUR;
    acciones: detalles, instalar en terminal (`paru -S`, `yay -S` o `sudo pacman -S`), copiar nombre, abrir en la web.
  - El IPC sigue siendo `nixsearch` (toggle/open/close) para no romper tus binds.
  - Falta (fase 5): probar en una instalación Arch real y afinar el parseo de `-Ss` si tu helper imprime otro formato.
- [ ] **Fase 5** — variante Arch (tras pasar la shell a git).

## Autogen por WM

| WM | Carpeta | Archivos | Cómo se aplica |
|---|---|---|---|
| Hyprland | `~/.config/hypr/modules/appearance/autogen/` | `theme.lua`, `layouta.lua`, `animprofile.lua` | `hyprctl eval` en vivo; `hyprctl reload` al cambiar layout/perfil |
| Mango | `~/.config/mango/autogen/` | `theme.conf`, `layout.conf`, `animprofile.conf` | `mmsg setoption` en vivo; `reload_config` |
| Niri | `~/.config/niri/autogen/` | `theme.kdl`, `layout.kdl`, `animprofile.kdl` | "en vivo" reescribiendo `theme.kdl` cada 200 ms mientras arrastras; Niri recarga solo al guardar |

Los nombres de Hyprland (incluido `layouta.lua`) son los que ya tenías.

### Niri: lo que tus dotfiles deben incluir
`include` es posicional (pisa lo anterior): ponlo AL FINAL de `config.kdl`.
`optional=true` y `~/` requieren niri 26.04+; con 25.11 usa ruta absoluta y sin `optional`.
```
include optional=true "~/.config/niri/autogen/theme.kdl"
include optional=true "~/.config/niri/autogen/layout.kdl"
include optional=true "~/.config/niri/autogen/animprofile.kdl"
```

### Equivalencias en Niri (apariencia → KDL)
Cada archivo es dueño de sus secciones, así no se pisan entre sí:
| Archivo | Contenido |
|---|---|
| `theme.kdl` | `layout` (gaps, borde, sombra), `window-rule` (esquinas, opacidad, blur), `blur {}` |
| `layout.kdl` | `layout { default-column-display }` |
| `animprofile.kdl` | `animations` completo: `off`, o el perfil con sus subsecciones |

| Opción de la shell | Niri |
|---|---|
| Gaps out | `layout { gaps N }` (Gaps in no se usa en Niri y su slider se oculta) |
| Border size | `> 0`: `border { on; width N }` + `focus-ring { off }`. `0`: `border { off }` y el focus-ring queda como lo tengas |
| Rounding | `window-rule { geometry-corner-radius N; clip-to-geometry true }` |
| Opacidad activa / inactiva | Desactivada en Niri: no se escribe nada y los sliders se ocultan |
| Sombras | `layout { shadow { on/off; softness N } }` |
| Blur | `window-rule { background-effect { blur true } }` + `blur { passes; offset }` (niri 26.04+, solo se ve con ventanas semitransparentes) |
| Animaciones | `animations { off }` si están apagadas |
| Perfil de animación | `animations { workspace-switch, window-open, window-close, horizontal-view-movement, window-movement, window-resize, config-notification-open-close, screenshot-ui-open, overview-open-close }` por perfil (resortes y easings) |
| Layout | `layout { default-column-display "normal" | "tabbed" }` |

Notas de Niri (de la doc):
- `is-active` SÍ es un matcher válido de `window-rule`.
- Una `window-rule` sin `match` con `opacity 1` pisaría las reglas por app de tu config; por eso ya no se escribe.
- `off` y `slowdown` son campos directos de `animations` y se mezclan entre includes; las subsecciones
  (`window-open`, `workspace-switch`…) NO se mezclan: se reemplazan enteras. Como el include va al final,
  `animprofile.kdl` pisa las animaciones de tu `config.kdl`. Si quieres tus propias animaciones, apaga el perfil
  quitando el include de `animprofile.kdl`.
- Si ya tienes `focus-ring`/`border` con colores en tu config, déjalos ahí: la shell solo toca `on/off` y el grosor.
- Verifica con `niri validate` tras el primer cambio. Si el `include optional=true`/`~/` falla en tu versión
  (anterior a 26.04), toda la config se rechaza y no se aplica nada: usa ruta absoluta y sin `optional`.

## A verificar en tus sesiones (escrito según la doc, sin probar)
- `niri msg action toggle-overview`, `focus-window --id`, `focus-workspace`, `focus-monitor`,
  `switch-layout next`, `quit --skip-confirmation`.
- Formato de `niri msg --json event-stream` y de `niri msg --json outputs` (`logical {x,y,width,height,scale}`).
- Que los perfiles de animación de Niri se sientan bien (los valores son una primera propuesta; ajústalos en `niriAnimDefs`).
- `shadow { off }` (la doc muestra `off` en los ejemplos de shadow).
- Hyprland: en el `config` de Hyprland debe seguir existiendo tu `require` del autogen, como hasta ahora.

## Pendientes menores
- `CAPS/CapsOSD.qml` lee Caps Lock con `hyprctl devices -j` (si no está, cae a `/sys/class/leds`).
- `MONITOR/MonitorEditor.qml` y la sección de monitores de `AdvancedSettings.qml` usan `hyprctl`: solo se ven en Hyprland.
- Textos de ayuda de Ajustes que mencionan `animprofile.lua` / "recarga Hyprland" siguen siendo específicos de Hyprland.
- Niri no informa fullscreen: las barras y la píldora no se esconden con un juego a pantalla completa.
- Niri: las ventanas fuera de la vista no aparecen en las miniaturas del Overview propio.
- `HyprDispatch.qml` sigue existiendo (foco y workspace de Hyprland).

## Fase 5 — qué sigue
- `PacSearch.qml` de la variante Arch queda obsoleto: portar solo lo que falte (p. ej. desinstalar) a `PackageSearch`.

## Checklist de pruebas (por WM)
1. Ajustes > Global-Manager: detecta WM y distro; avisa si eliges otro WM del que corre.
2. Barra y píldora: chips de workspaces con caja (1–10), activo = número resaltado, urgente ♡, click cambia de workspace.
   Niri: solo aparece el actual. El workspace activo se ve como el número resaltado (caja invertida), sin ❄.
3. Overview (atajo): tarjetas, miniaturas, click enfoca ventana, teclas 1–9.
4. Botón de workspaces: Hyprland/Mango abren la vista propia; Niri abre el overview nativo desde el Dashboard, la barra, el chip de la píldora y el IPC `overview` (toggle/open/close).
5. Launcher en modo Ventanas; Mpris "ir a la app".
6. Fullscreen (video/juego): barras y píldora se esconden (no aplica en Niri).
7. Cambiar layout de teclado: etiqueta y OSD.
8. Apariencia: mover un slider (en vivo en Hyprland y Mango; Niri al soltar), cambiar layout, perfil de animación,
   modo performance. Revisar que se creen los archivos de autogen de tu WM.
9. Menú de energía: cerrar sesión, reiniciar y apagar en los tres WM.

## Ronda actual
- Niri: el botón de workspaces es coherente en todas partes (Dashboard, barra, píldora, IPC) y abre el overview nativo
  (`toggle-overview` / `open-overview` / `close-overview`).
- Apariencia en vivo en Niri: al arrastrar un slider se reescribe `theme.kdl` cada 200 ms (Niri recarga solo).
  Claves en vivo: gapsOut, borderSize, rounding, blur*, shadow*. Hyprland y Mango siguen sin cambios.
  Pendiente de verificar: que la recarga continua no parpadee; si pasa, sube `interval` en `niriLiveTimer`.
