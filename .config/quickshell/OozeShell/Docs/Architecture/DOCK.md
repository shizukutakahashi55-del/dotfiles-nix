# DOCK — barra de apps fijadas y abiertas

- Qué es: un panel por monitor (`Variants` sobre `Quickshell.screens`, namespace `quickshell-dock`) con las
  apps fijadas y las abiertas. Se pega al borde opuesto a la barra horizontal, o arriba/abajo si la barra es
  vertical (`Theme.dockEffectivePosition`). Clic activa/minimiza, clic central cierra, clic derecho abre el menú.
- Archivos:
  - `Modules/Dock/Dock.qml` → ventana, panel (`FusedPanel`), tooltip, menú y auto-hide
  - `Modules/Dock/DockBackend.qml` → singleton con las apps fijadas (`dockPins` en `StateStore`)
  - `Settings/pages/DockPage.qml` → ajustes (estado, posición, modo, tamaño, altura, opacidad, blur)

## Ajustes (`ui.toml`)

| Clave | Propiedad en `Theme` | Rango | Efecto |
|---|---|---|---|
| `dockEnabled` | `dockEnabled` | on/off | muestra el dock (`dockUsable` también exige que no haya marco curvo) |
| `dockAutoHide` | `dockAutoHide` | on/off | oculta el dock y libera la zona reservada |
| `dockMode` | `dockMode` | `panel` / `pill` | fusionado al borde o cápsula flotante con hueco (`dockFloatGap`) |
| `dockScale` | `dockScalePercent` | 50–150 | escala iconos, celdas y ancho |
| `dockHeight` | `dockHeightPercent` | 85–160 | grosor de la barra; **no** escala los iconos |
| `dockOpacity` / `dockBlur` | `dockOpacity` / `dockBlur` | 0–100 | fondo y desenfoque del compositor |

Tamaño y altura son independientes: `pillHeight = 58 × dockScale × dockHeightFactor`. Con altura 100 % el
dock queda como antes. El mínimo de 85 % garantiza que la celda (`46 × dockScale`) siempre quepa dentro de la
barra; si se baja ese mínimo, los iconos se saldrán del panel.

## Comportamientos

- **Zona reservada**: con auto-hide apagado el dock reserva espacio (`exclusiveZone`) y las ventanas no
  quedan debajo de él, también con el marco de esquinas activo. Con auto-hide encendido la zona es `-1` y el
  dock se encima a las apps al aparecer.
- **Modo píldora sin borde**: la cápsula no dibuja contorno, así que con opacidad 0 % no queda ningún trazo
  visible. El estilo `cozy` sigue dibujando su borde de tinta, porque lo decide `FusedPanel`.
- **Nueva ventana** (menú contextual): usa la acción `new-window` del `.desktop` si existe (Brave, Firefox,
  Nautilus…); si no, ejecuta la entrada normal. Apps de instancia única (p. ej. Discord) solo se enfocan.

## Puntos a vigilar

- `exclusiveZone` / `reserveZone` (`Dock.qml`): la zona incluye `handleHeight + clearance − gapsOut` para dejar
  aire bajo las ventanas. Si cambias los `gapsOut` del compositor o la altura, revisa que ese aire no quede
  negativo (ya se limita con `Math.max(0, …)`) ni se duplique con el hueco del compositor.
- `newWindow()` (`Dock.qml`): depende del `id` de la acción en el `.desktop`. Es el lugar a ampliar si una app
  usa otro nombre (`new_window`, `NewWindow` ya se aceptan; variantes como `open-new-window` no).
- `implicitHeight` (`Dock.qml`): suma `pillHeight` y los márgenes de tooltip/menú. Si la altura máxima sube
  mucho, el tooltip (`maxDepth`) se recorta antes que el panel crezca; ajusta `tipAllowance` en ese caso.
- `dockUsable` (`Theme.qml`): oculta el dock con el marco curvo; no lo reutilices para decidir la zona
  reservada, que depende solo de `dockAutoHide`.
