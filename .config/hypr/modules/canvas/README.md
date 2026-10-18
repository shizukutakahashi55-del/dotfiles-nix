# Infinite Canvas en este dotfiles

Versión adaptada de `infinite-canvas-hyprland` (Asterrooid, MIT) a
`hyprland.lua` + módulos. Origen intacto en `~/Downloads/InfCanvas/`.

## Requisito previo (NixOS, declarativo)

El daemon de paneo necesita `evdev` y el grupo `input`. Sin esto,
toggle y zoom funcionan igual, solo falla el paneo por gestos
(mira `/tmp/infinite-desktop.log`):

``` nix
environment.systemPackages = with pkgs; [
  (python3.withPackages (ps: with ps; [ evdev ]))
  jq
];
users.users.oozenix.extraGroups = [ "input" ];
```

## Binds activos (`modules/canvas/canvas.lua`)

| Bind | Acción |
| :--- | :--- |
| `SUPER + ALT + D` | Toggle tiled <-> canvas |
| `SUPER + ALT + scroll` | Zoom focal in/out (en ALT: `CTRL+scroll` es zoom de apps) |
| `SUPER + ALT + 0` | Reset zoom |

## No incluidos a propósito (conflictos)

| Original canvas | Aquí manda |
| :--- | :--- |
| `SUPER + D` toggle | Clipboard de OozeShell (`keybinds.lua`) |
| `SUPER + flechas` centrar | Focus de `keybinds.lua` |
| `SUPER + SHIFT + flechas` | Move de `keybinds.lua` |
| `SUPER + CTRL + flechas` resize | Libre si lo quieres añadir |
| `SUPER + Z / X` workspaces | `SUPER + X` es minimizar aquí |

## Compatibilidad OozeShell

-   La barra es layer-shell: el canvas flota ventanas por debajo,
    no la tapa ni le roba foco.
-   `SUPER + D` sigue siendo clipboard; el canvas usa `ALT + D`.
-   Overview/workspaces de OozeShell no tocan el layout del canvas
    (vive en el compositor).

## Probar (en sesión Hyprland)

``` bash
hyprctl reload
# SUPER + ALT + D con 2-3 ventanas abiertas
tail -f /tmp/infinite-desktop.log
```
