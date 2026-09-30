#!/usr/bin/env bash

# ============================================================================
#  OOZENIX INSTALLER
#  Derived from setup-permissions.sh: adds distro detection, dependency
#  installation, and unzipping OozeShell BEFORE running the same
#  symlink + permissions logic from the original installer.
#
#  Real support: Arch Linux and NixOS. Any other distro is treated as
#  "non-Arch" and only gets the NixOSInstallation.md file with the
#  dependency list to install by hand (or adapt to their distro).
# ============================================================================

set -e

DOTFILES="$HOME/dotfiles"
NIXOS_MD="$DOTFILES/NixOSInstallation.md"
QS_DIR="$DOTFILES/.config/quickshell"

INSTALL_LEGACY=false   # swaync / waybar / swayosd / wlogout / rofi

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
ask_yes_no() {
  local reply
  while true; do
    read -r -p "$1 [y/n]: " reply
    case "$reply" in
      [yY]*) return 0 ;;
      [nN]*) return 1 ;;
      *) echo "    Please answer y/n." ;;
    esac
  done
}

create_symlink() {
  local source="$1"
  local target="$2"

  if [ ! -e "$source" ]; then
    echo "  [✗] Source does not exist: $source"
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$source" ]; then
      echo "  [✓] Already linked: $target"
      return
    fi
    echo "  [!] Replacing existing symlink: $target"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "  [!] Target already exists (not a symlink): $target"
    echo "      Skipping to avoid overwriting real files."
    return
  fi

  ln -s "$source" "$target"
  echo "  [✓] Linked: $target -> $source"
}

echo "=========================================="
echo "      Installing Oozenix / OozeShell"
echo "=========================================="
echo

if [ ! -d "$DOTFILES" ]; then
  echo "[✗] Dotfiles directory not found: $DOTFILES"
  exit 1
fi
echo "[✓] Dotfiles directory found: $DOTFILES"
echo

# ----------------------------------------------------------------------------
# 1. Arch Linux?
# ----------------------------------------------------------------------------
IS_ARCH=false
if ask_yes_no "Are you using Arch Linux?"; then
  IS_ARCH=true
fi

# ============================================================================
# 2a. ARCH BRANCH — installs real dependencies and unzips OozeShell-arch.zip
# ============================================================================
if $IS_ARCH; then
  echo
  echo "── Arch Linux ────────────────────────────────────────────────"

  AUR_HELPER=""
  for h in paru yay; do
    command -v "$h" >/dev/null 2>&1 && AUR_HELPER="$h" && break
  done

  if [ -z "$AUR_HELPER" ]; then
    echo "[!] No AUR helper found (paru/yay). Several packages"
    echo "    (quickshell-git, hyprshot, matugen, etc.) only live in the AUR."
    if ask_yes_no "Install 'paru' now?"; then
      sudo pacman -S --needed --noconfirm base-devel git
      git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
      (cd /tmp/paru-bin && makepkg -si --noconfirm)
      AUR_HELPER="paru"
    else
      echo "    Continuing with official packages only; install the AUR ones by hand later."
    fi
  fi
  echo "[✓] AUR helper: ${AUR_HELPER:-none}"
  echo

  install_pacman() { [ "$#" -eq 0 ] && return; sudo pacman -S --needed --noconfirm "$@"; }
  install_aur() {
    [ "$#" -eq 0 ] && return
    if [ -n "$AUR_HELPER" ]; then
      "$AUR_HELPER" -S --needed --noconfirm "$@"
    else
      echo "  [!] Skipped (needs AUR, no helper): $*"
    fi
  }

  # --- Base: official repos ---
  PACMAN_BASE=(
    hyprland hyprpaper hypridle hyprlock
    qt6-base qt6-declarative qt6-quickcontrols2 qt6-svg qt6-shadertools qt6ct
    wireplumber brightnessctl power-profiles-daemon networkmanager network-manager-applet
    playerctl bluez bluez-utils blueman
    mpv ffmpeg socat wl-clipboard
    libnotify imagemagick wtype grim slurp cava pavucontrol
  )

  # --- Base: AUR only ---
  # "Quickshell-Wrapper": per your confirmation, this isn't a separate
  # package — it's quickshell-git plus the Qt Quick modules above. Not
  # installed separately.
  AUR_BASE=(
    hyprpolkitagent hyprshot hyprsunset hyprshutdown hyprsysteminfo
    quickshell-git
    ttf-jetbrains-mono-nerd
    matugen mpvpaper
    wev
    awww-git   # current successor to swww, confirmed with you
  )

  echo "Installing base dependencies (pacman)..."
  install_pacman "${PACMAN_BASE[@]}"
  echo "Installing base dependencies (AUR)..."
  install_aur "${AUR_BASE[@]}"
  echo

  # --- Terminal ---
  echo "Choose your terminal:"
  select TERM_CHOICE in foot kitty alacritty wezterm ghostty "Already installed"; do
    case "$TERM_CHOICE" in
      foot|kitty|alacritty|wezterm) install_pacman "$TERM_CHOICE"; break ;;
      ghostty) install_aur ghostty; break ;;
      "Already installed") break ;;
      *) echo "Invalid option." ;;
    esac
  done
  echo

  # --- NixSearch (optional) ---
  if ask_yes_no "Install NixSearch (nix + nix-search-cli, optional)?"; then
    install_aur nix-search-cli
    if ! command -v nix >/dev/null 2>&1; then
      echo "  Installing Nix (official multi-user installer)..."
      sh <(curl -L https://nixos.org/nix/install) --daemon
    fi
  fi
  echo

  # --- Tools OozeShell replaces ---
  if ask_yes_no "OozeShell already integrates the bar/notifications/launcher/logout. Install swaync, waybar, swayosd, wlogout and rofi anyway, in case you want them separately?"; then
    INSTALL_LEGACY=true
    install_pacman swaync waybar rofi
    install_aur wlogout swayosd
  fi
  echo

  # --- Extras ("Continue next") ---
  if ask_yes_no "Also install the extras bundle (dev tools, gaming, misc utilities)?"; then
    PACMAN_EXTRA=(
      greetd udisks2 rtkit flatpak zip unzip yazi neovim starship
      fd ripgrep jq dolphin nomacs gamemode lutris mangohud wine
      curl git github-cli jdk21-openjdk lazygit python python-pip tree
      qt6-quick3d wget vim
    )

    AUR_EXTRA=(
      greetd-tuigreet bibata-cursor-theme prismlauncher protonplus protontricks
      goverlay vscodium-bin nixd nixfmt python-uv pw-viz ruff
    )
    install_pacman "${PACMAN_EXTRA[@]}"
    install_aur "${AUR_EXTRA[@]}"
  fi

  echo
  echo "[✓] Unzipping OozeShell-arch.zip..."
  mkdir -p "$QS_DIR"
  if [ -f "$DOTFILES/OozeShell-arch.zip" ]; then
    unzip -o "$DOTFILES/OozeShell-arch.zip" -d "$QS_DIR"
  else
    echo "  [✗] Could not find $DOTFILES/OozeShell-arch.zip"
    echo "      Put it there and re-run the installer."
    exit 1
  fi

# ============================================================================
# 2b. NON-ARCH BRANCH — treated as NixOS
# ============================================================================
else
  echo
  echo "── Non-Arch distro (treated as NixOS) ──────────────────────────"
  echo "I only give real support to NixOS and Arch. If you're on another"
  echo "distro, the dependency list still lands in $NIXOS_MD for you to adapt."
  echo

  HAVE_UNZIP=false
  if command -v unzip >/dev/null 2>&1; then
    HAVE_UNZIP=true
  fi

  if ! $HAVE_UNZIP; then
    echo "[!] I can't find 'unzip' installed."
    if ask_yes_no "Can I open a temporary nix-shell with unzip to extract it (installs nothing permanent)?"; then
      mkdir -p "$QS_DIR"
      if [ -f "$DOTFILES/OozeShell.zip" ]; then
        nix-shell -p unzip --run "unzip -o '$DOTFILES/OozeShell.zip' -d '$QS_DIR'"
        HAVE_UNZIP=true
      else
        echo "  [✗] Could not find $DOTFILES/OozeShell.zip — put it there and re-run the installer."
        exit 1
      fi
    else
      echo "  [✗] Without unzip I can't continue with this step."
      echo "      Extract OozeShell.zip by hand into $QS_DIR and re-run the installer."
      exit 1
    fi
  else
    echo "[✓] Unzipping OozeShell.zip..."
    mkdir -p "$QS_DIR"
    if [ -f "$DOTFILES/OozeShell.zip" ]; then
      unzip -o "$DOTFILES/OozeShell.zip" -d "$QS_DIR"
    else
      echo "  [✗] Could not find $DOTFILES/OozeShell.zip"
      echo "      Put it there and re-run the installer."
      exit 1
    fi
  fi

  echo
  if ask_yes_no "OozeShell already integrates the bar/notifications/launcher/logout. Set up the swaync, waybar, swayosd, wlogout and rofi configs anyway, in case you ever want them?"; then
    INSTALL_LEGACY=true
  fi

  echo
  echo "[i] Writing $NIXOS_MD with the dependency list..."
  cat > "$NIXOS_MD" << 'EOF'
# Oozenix / OozeShell dependencies for NixOS

This list is the same one the Arch branch of the installer uses, phrased as
"what you need available" rather than exact Nix attribute names (those can
vary between channels/overlays).

You can also skip all of this by using directly:

- Ready-made system config: https://github.com/shizukutakahashi55-del/nix-home
- User dotfiles ready for OozeShell: https://github.com/shizukutakahashi55-del/dotfiles-nix
 

## Base

- Hyprland: hyprland, hyprpolkitagent, hyprpaper, hyprshot, hyprsunset,
  hyprshutdown, hyprsysteminfo, hypridle, hyprlock
- Quickshell (quickshell-git) — includes the Qt Quick wrapper/dependencies
- Qt6: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Shapes,
  QtQuick.Effects, QtQml, qt6ct
- Nerd Font: "JetBrainsMono Nerd Font"
- wpctl (wireplumber)
- brightnessctl
- powerprofilesctl (power-profiles-daemon)
- nmcli (NetworkManager) + networkmanagerapplet
- playerctl
- bluetoothd (BlueZ) / Blueman
- matugen
- mpvpaper (+ mpv)
- ffmpeg
- socat
- wl-copy (wl-clipboard)
- pgrep
- A terminal: foot, kitty, alacritty, wezterm, or ghostty
- libnotify
- imagemagick
- wtype
- wev
- grim
- slurp
- cava
- pavucontrol
- awww (current successor to swww)

## Optional — NixSearch

- nix-search / nix-search-cli
- nix (nix shell / nix profile install from NixSearch)

If not installed, the rest of OozeShell still works.

## Optional — tools OozeShell replaces

No longer needed for normal use (bar, notifications, launcher, logout are
already integrated into OozeShell), but the configs stay in the dotfiles in
case you want to use them separately:

- swaync
- waybar
- swayosd
- wlogout
- rofi

## Extras (dev tools, gaming, utilities)

greetd, udisks2, pw-viz, rtkit, wireplumber, flatpak, zip, unzip, yazi,
neovim, starship, fd, ripgrep, jq, dolphin, nomacs, Adwaita-style dark
theme, Bibata-Modern-Classic cursors, gamemode, lutris, mangohud,
prismlauncher, protonplus, wine, protontricks, goverlay, curl, git, gh,
jdk21, lazygit, python3, python3Packages.pip, vscodium-fhs, nixd,
nixfmt-rfc-style, nix-search-cli, ruff, tree, qt6.qtquick3d,
qt6.qtdeclarative, uv, wget, vim
EOF
  echo "[✓] Done: $NIXOS_MD"
fi

# ============================================================================
# 3. From here on: same logic as setup-permissions.sh (symlinks + permissions)
# ============================================================================
echo
echo "=========================================="
echo "     Creating symlinks and permissions"
echo "=========================================="
echo

mkdir -p "$HOME/.config" "$HOME/.local/bin"

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
  "wezterm"
  "yazi"
  "starship.toml"
)

if $INSTALL_LEGACY; then
  config_items+=("rofi" "swaync" "swayosd" "waybar")
fi

for item in "${config_items[@]}"; do
  create_symlink "$DOTFILES/.config/$item" "$HOME/.config/$item"
done

# Special-cased target paths
create_symlink "$DOTFILES/.config/VK-Th" "$HOME/.config/Vesktop/Themes"

echo
echo "Creating home & binary symlinks..."

create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"

echo
echo "Granting execution permissions..."

scripts=(
  "$DOTFILES/nix-rofi"
)

if $INSTALL_LEGACY; then
  scripts+=(
    "$DOTFILES/.config/rofi/Launcher/launcher.sh"
    "$DOTFILES/.config/rofi/Powermenu/powermenu.sh"
    "$DOTFILES/.config/rofi/Bluetooth/bluetooth.sh"
    "$DOTFILES/.config/waybar/themes/waybar-theme-switcher.sh"
  )
fi

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
echo "       Oozenix installation complete!"
echo "=========================================="
