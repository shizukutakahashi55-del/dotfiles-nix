# Transiciones de fondo

Documento de referencia de las animaciones al cambiar de wallpaper.
Código: `src/transition.rs` (catálogo, frames, awww, mpv), `src/layerbg.rs` (capa propia),
`src/engine.rs` (enrutado por backend), `src/actions.rs` y `src/cli.rs` (opciones).

## Configuración

| Clave | Valores | Por defecto |
|---|---|---|
| `transition` | `none` `fade` `slide-left` `slide-right` `slide-up` `slide-down` `wipe-left` `wipe-right` `wipe-up` `wipe-down` `circle` `zoom` `blinds` `random` | `fade` |
| `transition_ms` | 100 – 3000 | 600 |

Los nombres con dirección indican el **borde por donde entra** el fondo nuevo.

CLI:

- `oozewalls set transition <tipo>` / `oozewalls set transition_ms <ms>`
- `oozewalls transitions [--json]` lista los tipos y el valor actual
- `oozewalls apply <archivo> --transition <tipo> --transition-duration <ms>` sobrescribe solo esa llamada
- `oozewalls apply <archivo> --no-transition` desactiva la animación solo esa llamada

`restore` (autoinicio) nunca anima. `random` elige un tipo concreto en cada cambio.

## Cómo se anima según el backend

### Imágenes con la capa propia (`static_backend builtin`)

El proceso `__bg` es **residente**: mantiene la misma superficie de capa y recibe los cambios por un socket (`bg_<salida>.bgsock`, comando `SET <tipo> <ms> <scaling> <archivo>`). No se crea ni destruye ninguna superficie al cambiar de fondo. Esto evita las animaciones de apertura/cierre de capas del compositor (por ejemplo Hyprland), que se sumaban a la propia y producían parpadeo.

Cambio con proceso residente:

1. El padre (`spawn`) conecta al socket y envía `SET`.
2. El hijo decodifica en paralelo la imagen anterior (la que está mostrando) y la nueva, responde `ok` y el padre regresa.
3. El hijo anima sobre la misma superficie (`frame_into`, tiempo real, ~60 fps, easing cúbico) y deja el frame final como buffer estático.
4. Si llega otro cambio mientras anima, espera a que termine; si llegan varios, solo se aplica el último.

Primer lanzamiento (no hay proceso residente) o cuando hay un video activo:

1. El padre busca la imagen anterior en la config (`wallpapers`, `current`; si era video usa su miniatura). Sin anterior, o si es el mismo archivo, no hay animación.
2. Se lanza `__bg` con tipo, duración y ruta de la anterior.
3. El hijo pinta primero un frame idéntico al fondo actual, hace `roundtrip` con el compositor e imprime `ready`. El padre baja el proceso viejo en ese momento.
4. Luego anima. Cada frame es un buffer opaco con la mezcla completa anterior→nueva, así funciona aunque el compositor ponga la capa nueva debajo de la vieja.

Memoria: durante la animación hay dos imágenes en RAM por monitor; al terminar queda un único buffer.

### Imágenes con awww

Se pasa `--transition-type`, `--transition-duration` y `--transition-fps 60`:

| Nuestro tipo | awww |
|---|---|
| fade | fade |
| slide-* y wipe-* | left / right / top / bottom |
| circle | center |
| zoom | grow |
| blinds | wave |
| random | random |
| none | none |

### Video en vivo (mpvpaper / OozeWalls)

Se usan propiedades de mpv por el socket IPC, en dos mitades (salida y entrada):

- Al cambiar de video con mpv ya abierto: rampa de salida, `loadfile`, rampa de entrada.
- Al lanzar mpvpaper nuevo: arranca con las propiedades "de entrada" como opciones y luego se rampa a 0.

| Tipo | Efecto en video |
|---|---|
| slide-* | `video-pan-x/y` fuera y dentro de pantalla |
| zoom | desvanecido + `video-zoom` en la entrada |
| el resto | desvanecido por `brightness` (pasa por negro) |

Un video sobre un fondo estático (o al revés) se superpone y luego se libera el anterior.

## Pruebas

- Unitarias (`cargo test --lib`): cada tipo empieza igual al fondo anterior, termina igual al nuevo y mezcla a mitad de camino.
- Manual en sway headless: capturas con `grim` durante `circle`, `slide-left` y `fade`; el PID del proceso residente no cambia entre cambios; cambios encadenados sin bajón a negro.
