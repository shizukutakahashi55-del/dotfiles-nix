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

# ----------------------------------------------------------------------------
# Check dotfiles directory
# ----------------------------------------------------------------------------

if [ ! -d "$DOTFILES" ]; then
    echo "[✗] Dotfiles directory not found: $DOTFILES"
    exit 1
fi

echo "[✓] Dotfiles directory found: $DOTFILES"
echo

# ----------------------------------------------------------------------------
# Create required directories
# ----------------------------------------------------------------------------

echo "Creating required directories..."

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"

echo "  [✓] ~/.config"
echo "  [✓] ~/.local/bin"
echo

# ----------------------------------------------------------------------------
# Function: create symlink
# ----------------------------------------------------------------------------

create_symlink() {
    local source="$1"
    local target="$2"

    # Remove existing symlink pointing to the correct location
    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            echo "  [✓] Already linked: $target"
            return
        fi

        echo "  [!] Replacing existing symlink: $target"
        rm "$target"

    # Existing file or directory
    elif [ -e "$target" ]; then
        echo "  [!] Target already exists: $target"
        echo "      Skipping to avoid overwriting."
        return
    fi

    ln -s "$source" "$target"
    echo "  [✓] Linked: $target -> $source"
}

# ----------------------------------------------------------------------------
# .config directories
# ----------------------------------------------------------------------------

echo "Creating .config symlinks..."

create_symlink "$DOTFILES/.config/cava"       "$HOME/.config/cava"
create_symlink "$DOTFILES/.config/fastfetch"  "$HOME/.config/fastfetch"
create_symlink "$DOTFILES/.config/hypr"       "$HOME/.config/hypr"
create_symlink "$DOTFILES/.config/kitty"      "$HOME/.config/kitty"
create_symlink "$DOTFILES/.config/matugen"    "$HOME/.config/matugen"
create_symlink "$DOTFILES/.config/rofi"       "$HOME/.config/rofi"
create_symlink "$DOTFILES/.config/swaync"     "$HOME/.config/swaync"
create_symlink "$DOTFILES/.config/swayosd"    "$HOME/.config/swayosd"
create_symlink "$DOTFILES/.config/waybar"     "$HOME/.config/waybar"
create_symlink "$DOTFILES/.config/yazi"       "$HOME/.config/yazi"
create_symlink "$DOTFILES/.config/quickshell" "$HOME/.config/quickshell"
create_symlink "$DOTFILES/.config/VK-Th"      "$HOME/.config/Vesktop/Themes"

# ----------------------------------------------------------------------------
# Individual config files
# ----------------------------------------------------------------------------

echo
echo "Creating config file symlinks..."

create_symlink "$DOTFILES/.config/starship.toml" "$HOME/.config/starship.toml"

# ----------------------------------------------------------------------------
# Home configuration files
# ----------------------------------------------------------------------------

echo
echo "Creating home directory symlinks..."

create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"

# ----------------------------------------------------------------------------
# Local binaries
# ----------------------------------------------------------------------------

echo
echo "Creating local binary symlinks..."

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
    "$DOTFILES/.config/quickshell/OozeShell-KDE/binds.sh"
    "$DOTFILES/.config/quickshell/OozeShell-KDE/lang.sh"
    "$DOTFILES/.config/quickshell/OozeShell-KDE/launcher.sh"
    "$DOTFILES/.config/quickshell/OozeShell-KDE/oozerunner.sh"
    "$DOTFILES/.config/quickshell/OozeShell-KDE/walls.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "  [✓] Executable: $script"
    else
        echo "  [✗] File not found: $script"
    fi
done

# ----------------------------------------------------------------------------
# Finished
# ----------------------------------------------------------------------------

echo
echo "=========================================="
echo "       Dotfiles installation complete!"
echo "=========================================="
echo
echo "You may need to restart your PC."
echo
