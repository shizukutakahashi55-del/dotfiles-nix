#!/usr/bin/env bash

# ============================================================================
#  DOTFILES INSTALLER
#  Creates symlinks and applies execution permissions.
# ============================================================================

set -e

DOTFILES="$HOME/dotfiles"

echo "=========================================="
echo "        Installing Oozenix Dotfiles"
echo "=========================================="
echo

if [ ! -d "$DOTFILES" ]; then
    echo "[✗] Dotfiles directory not found: $DOTFILES"
    exit 1
fi

echo "[✓] Dotfiles directory found: $DOTFILES"
echo

mkdir -p "$HOME/.config" "$HOME/.local/bin"

# ----------------------------------------------------------------------------
# Function: create symlink safely
# ----------------------------------------------------------------------------

create_symlink() {
    local source="$1"
    local target="$2"

    # Verificar que el origen exista en ~/dotfiles
    if [ ! -e "$source" ]; then
        echo "  [✗] Source does not exist: $source"
        return
    fi

    # Crear directorio padre si no existe (ej: ~/.config/Vesktop)
    mkdir -p "$(dirname "$target")"

    # Si ya es un enlace apuntando al lugar correcto
    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            echo "  [✓] Already linked: $target"
            return
        fi

        echo "  [!] Replacing existing symlink: $target"
        rm "$target"

    # Si existe un archivo/directorio real, no sobrescribir
    elif [ -e "$target" ]; then
        echo "  [!] Target already exists (not a symlink): $target"
        echo "      Skipping to avoid overwriting real files."
        return
    fi

    ln -s "$source" "$target"
    echo "  [✓] Linked: $target -> $source"
}

# ----------------------------------------------------------------------------
# .config directories & files
# ----------------------------------------------------------------------------

echo "Creating .config symlinks..."

config_items=(
    "alacritty"
    "cava"
    "fastfetch"
    "foot"
    "ghostty"
    "hypr"
    "kitty"
    "matugen"
    "nvim"
    "quickshell"
    "rofi"
    "swaync"
    "swayosd"
    "waybar"
    "wezterm"
    "yazi"
    "starship.toml"
)

for item in "${config_items[@]}"; do
    create_symlink "$DOTFILES/.config/$item" "$HOME/.config/$item"
done

# Casos especiales de rutas de destino
create_symlink "$DOTFILES/.config/VK-Th" "$HOME/.config/Vesktop/Themes"

# ----------------------------------------------------------------------------
# Home & Local Binaries
# ----------------------------------------------------------------------------

echo
echo "Creating home & binary symlinks..."

create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"

# ----------------------------------------------------------------------------
# Execution permissions
# ----------------------------------------------------------------------------

echo
echo "Granting execution permissions..."

scripts=(
    "$DOTFILES/nix-rofi"
    "$DOTFILES/.config/rofi/Launcher/launcher.sh"
    "$DOTFILES/.config/rofi/Powermenu/powermenu.sh"
    "$DOTFILES/.config/rofi/Bluetooth/bluetooth.sh"
    "$DOTFILES/.config/waybar/themes/waybar-theme-switcher.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "  [✓] Executable: $script"
    else
        echo "  [✗] Script file not found: $script"
    fi
done

echo
echo "=========================================="
echo "       Dotfiles installation complete!"
echo "=========================================="