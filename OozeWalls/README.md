# OozeWalls

Motor mínimo de wallpapers live/estático vía `mpvpaper`, con app propia
standalone y CLI controlable todo desde Quickshell sin abrir ajustes.

## App (launcher)

```
./install.sh
```

Busca `OozeWalls` en el launcher. Biblioteca por carpetas, Ajustes, Estado.
Click selecciona, doble click aplica. Funciona sin Quickshell.

## CLI

```
oozewalls apply ~/Videos/wall.mp4 --output "*"
oozewalls status --json
oozewalls list --json
oozewalls browse --path ~/Videos/Wallpapers --json
oozewalls dirs-add ~/Pictures/Video-Wallpapers
```

## Transiciones

`oozewalls set transition fade|slide-left|wipe-up|circle|zoom|blinds|random|none` y `oozewalls set transition_ms 600`. Ver `docs/TRANSICIONES.md`.

## Autoinicio y paleta

- `oozewalls restore` reaplica el fondo guardado (ponlo en `exec-once` de tu compositor, o usa `programs.oozewalls.autostart = true` en Home Manager).
- `oozewalls palette --scheme vibrant --index 0` genera la paleta matugen en `~/.cache/oozeshell/colors.json`; la GUI trae selector de esquema y colores fuente.

## Arquitectura

Ver `docs/ARCH.md`.

## Presupuesto

Meta ≤500 MB RSS con video activo. Imagen estática: capa propia `wl_shm`, pocos MB (sin `mpvpaper`).
Medido: 4K H264 ≈ 450-510 MB, 1080p ≈ 150-250 MB.

## Licencia

GPL-3.0-or-later.
