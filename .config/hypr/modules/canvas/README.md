# Infinite Canvas en este dotfiles

Versión adaptada de `infinite-canvas-hyprland` (Asterrooid, MIT) a
`hyprland.lua` + módulos, con el paneo reescrito en Lua puro.

- **Sin evdev, sin `python-evdev`, sin grupo `input`, sin root.**
- El paneo sólo consume CPU mientras arrastras (`hl.timer` de 16 ms).
- El único proceso persistente es `canvas_daemon.py` (socket2): auto-captura
  de ventanas nuevas en modo canvas. No lee `/dev/input`.

## Binds (`modules/canvas/canvas.lua`)

| Bind | Acción |
| :--- | :--- |
| `ALT + botón medio` (arrastrar) | **Pan del canvas** |
| `ALT + rueda arriba/abajo` | Zoom focal in/out (centrado en el cursor) |
| `ALT + 0` | Reset de zoom (585×520, recortado al monitor) |
| `SUPER + ALT + D` | Toggle tiled ↔ canvas |
| `SUPER + ALT + F` | **Fit**: encuadrar todas las tarjetas |
| `SUPER + ALT + H` | **Centrar** la ventana activa |
| `SUPER + ALT + G` | **Tidy**: grid ordenado por app |
| `SUPER + CTRL + flechas` | Navegar y centrar la siguiente tarjeta |
| `SUPER + ALT + flechas` | Mover la tarjeta flotante 90 px |
| `SUPER + CTRL + SHIFT + flechas` | Resize de la ventana |
| `SUPER + ALT + SHIFT + flechas` | Mover ventana en layout tiled |

Los binds usan `ALT` pero **no chocan con las teclas de Hyprland**: no hay
ningún bind solo-ALT en el resto de la config. `ALT+MMB` se consume, así que
no llega a las apps (nadie usa ese combo); `ALT+clic izquierdo` se deja libre
a propósito para no romper multi-cursor, "descargar enlace", etc.

## Ajustes rápidos

En `canvas.lua`:

| Constante | Default | Qué hace |
| :--- | :--- | :--- |
| `PAN_BUTTON` | `"mouse:274"` | Botón de paneo: `272` izq., `274` medio, `275` atrás |
| `PAN_SPEED` | `1.0` | Multiplicador de velocidad |
| `PAN_INVERT` | `false` | Invertir la dirección |
| `EDGE_WRAP` | `false` | `true` = al llegar al borde, el cursor salta al lado opuesto y el paneo sigue (infinito real, con salto visible del puntero) |
| `PAN_TICK_MS` | `16` | Frecuencia del paneo (~60 Hz) |

## Cómo funciona

- `floating_tile_toggle.py` convierte el workspace en tarjetas flotantes
  (layout guardado en `$XDG_RUNTIME_DIR/hypr_infinite_state.json`) o vuelve
  al layout tiled (`scrolling`).
- El pan mueve las ventanas flotantes del workspace activo con
  `hl.dsp.window.move({ relative = true })`, sin procesos externos.
- `canvas_daemon.py` escucha el socket2: al abrir una ventana en modo canvas
  la hace flotante y la coloca en el cursor.
- `canvas_fit.py`, `canvas_center.py` y `canvas_tidy.py` sólo se ejecutan
  cuando pulses su bind.

Nota: el "zoom" de este canvas **redimensiona ventanas**, no es una cámara
real (eso requeriría un plugin de compositor tipo Phantomat o Infinity Land).
Por eso el fit también reajusta el tamaño de las tarjetas.

## Requisitos (NixOS)

Nada especial: `python3` (ya está) y `hyprctl`. El antiguo requisito de
`evdev` + grupo `input` ya **no** es necesario para el paneo.

## Probar / depurar

```bash
hyprctl reload
hyprctl configerrors

# Abre 2-3 ventanas, cambia a canvas y prueba el ratón:
#   SUPER+ALT+D, ALT+MMB (pan), ALT+rueda (zoom), SUPER+ALT+F/H/G

tail -f /tmp/hypr-canvas.log     # daemon socket2
pgrep -af canvas_daemon
```

### El paneo se queda pegado

Hyprland 0.56 marca el bind de *release* del ratón como `shadowed` en cuanto el
bind de *press* consume el evento, así que el release nunca se dispara y el pan
sigue al cursor. Por eso el bind de release lleva `transparent = true` (no entra
en el cálculo de shadowing). No quites esa opción.

Además, `pan_tick` comprueba en cada tick que `ALT` siga pulsado y se detiene si
se suelta, aunque el release del ratón se pierda. `PAN_MAX_MS` es la última red
de seguridad.

Si el daemon está duplicado, el lock de `XDG_RUNTIME_DIR` hace que el segundo
salga solo. Para reiniciarlo tras editar el `.py`:

```bash
pkill -f canvas_daemon.py
python3 ~/.config/hypr/modules/canvas/scripts/canvas_daemon.py > /tmp/hypr-canvas.log 2>&1 &
```

## Compatibilidad OozeShell

- La barra es layer-shell: las ventanas del canvas quedan por debajo.
- `SUPER + D` sigue siendo clipboard; el canvas no lo toca.
- El layout tiled del dotfiles es `scrolling`; el canvas es el modo flotante.

## Rollback

El módulo anterior está en `modules/canvas.bak-20261021/`:

```bash
cd ~/.config/hypr/modules
rm -rf canvas
mv canvas.bak-20261021 canvas
hyprctl reload
```
