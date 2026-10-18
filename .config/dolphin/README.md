# Dolphin + OozeShell (portable)

Carpeta para llevar la integración a otros equipos. El tema por defecto
es el de OozeShell: esquema `OozeSoft` (lo genera matugen en cada máquina)
+ iconos Papirus + `dolphinrc` sin barra de menú y con previsualizaciones.

## Contenido

-   `dolphinrc`: defaults OozeShell. No incluye marcas de máquina.
-   `apply.sh`: instalador idempotente (respalda en `*.bak`, solo
    escribe lo que falta).

## Uso en otro equipo

1.  Instalar declarativamente (no imperativo):

    ``` nix
    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      papirus-icon-theme
      xdg-utils
    ];
    ```

2.  Aplicar:

    ``` bash
    bash ~/.config/dolphin/apply.sh --set-default
    ```

    Sin `--set-default` solo instala tema y config, sin tocar
    asociaciones MIME.

3.  Verificar:

    ``` bash
    xdg-mime query default inode/directory   # org.kde.dolphin.desktop
    dolphin "$HOME"
    ```

## Notas

-   `OozeSoft.colors` **no** se versiona: lo regenera OozeShell/matugen
    (`~/.local/share/color-schemes/`) a partir del wallpaper.
-   OozeShell ya trae: el catálogo `DefaultApps` incluye
    Dolphin y abre carpetas con `xdg-open`, así respeta esta asociación
    en Hyprland, Niri y MangoWM sin cambios por compositor.
-   Ver plan completo: `../quickshell/plan-integracion-dolphin-oozeshell.md`.
