#!/usr/bin/env bash

# ============================================================================
#  OOZENIX INSTALLER
#  Real support: Arch Linux and NixOS. Any other distro is treated as
#  "non-Arch" and only gets the NixOSInstallation.md file with the
#  dependency list to install by hand (or adapt to their distro).
# ============================================================================

set -euo pipefail

DOTFILES="$HOME/dotfiles"
NIXOS_MD="$DOTFILES/NixOSInstallation.md"
QS_DIR="$DOTFILES/.config/quickshell"
STAMP="$(date +%Y%m%d-%H%M%S)"

INSTALL_LEGACY=false   # swaync / waybar / swayosd / wlogout / rofi
IS_ARCH=false
HAS_NVIDIA=false        # solo Arch: activa las variables de entorno de Nvidia en env.lua
AUR_HELPER=""
FAILED=()              # paquetes que no se pudieron instalar (resumen final)

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
ask_yes_no() {
  local reply
  while true; do

    read -r -p "$1 [y/n]: " reply || { echo; return 1; }
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
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$source" ]; then
      echo "  [✓] Already linked: $target"
      return 0
    fi
    echo "  [!] Replacing existing symlink: $target"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "  [!] Target already exists (not a symlink): $target"
    if ask_yes_no "      Move it to ${target}.bak-${STAMP} and link the dotfiles version?"; then
      mv "$target" "${target}.bak-${STAMP}"
      echo "  [✓] Backup: ${target}.bak-${STAMP}"
    else
      echo "      Skipped (real file kept)."
      return 0
    fi
  fi

  ln -s "$source" "$target"
  echo "  [✓] Linked: $target -> $source"
}


extract_oozeshell() {
  local zip="$1" runner="${2:-}"
  mkdir -p "$QS_DIR"
  if [ -d "$QS_DIR/OozeShell" ]; then
    mv "$QS_DIR/OozeShell" "$QS_DIR/OozeShell.bak-${STAMP}"
    echo "  [✓] Previous OozeShell moved to $QS_DIR/OozeShell.bak-${STAMP}"
  fi
  if [ "$runner" = "nix" ]; then
    nix-shell -p unzip --run "unzip -qo '$zip' -d '$QS_DIR'"
  else
    unzip -qo "$zip" -d "$QS_DIR"
  fi
}

echo "=========================================="
echo "      Installing Oozenix / OozeShell"
echo "=========================================="
echo

if [ "$(id -u)" -eq 0 ]; then
  echo "[✗] Do not run this installer as root (makepkg refuses, and symlinks"
  echo "    would land in /root). Run it as your normal user; sudo is used"
  echo "    only where needed."
  exit 1
fi

if [ ! -d "$DOTFILES" ]; then
  echo "[✗] Dotfiles directory not found: $DOTFILES"
  exit 1
fi
echo "[✓] Dotfiles directory found: $DOTFILES"
echo

# ----------------------------------------------------------------------------
# 1. Arch Linux?
# ----------------------------------------------------------------------------
if ask_yes_no "Are you using Arch Linux?"; then
  IS_ARCH=true
  if [ ! -f /etc/arch-release ] || ! command -v pacman >/dev/null 2>&1; then
    echo "[!] This doesn't look like Arch (no /etc/arch-release or no pacman)."
    ask_yes_no "    Continue with the Arch branch anyway?" || exit 1
  fi
fi


if $IS_ARCH; then ZIP_FILE="$DOTFILES/OozeShell-arch.zip"; else ZIP_FILE="$DOTFILES/OozeShell.zip"; fi
if [ ! -f "$ZIP_FILE" ]; then
  echo "[✗] Could not find $ZIP_FILE"
  echo "    Put it there and re-run the installer."
  exit 1
fi
echo "[✓] Found $(basename "$ZIP_FILE")"

# ============================================================================
# 2a. ARCH BRANCH — installs real dependencies and unzips OozeShell-arch.zip
# ============================================================================
if $IS_ARCH; then
  echo
  echo "── Arch Linux ────────────────────────────────────────────────"

  for h in paru yay; do
    if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
  done

  if [ -z "$AUR_HELPER" ]; then
    echo "[!] No AUR helper found (paru/yay). Some packages (matugen, mpvpaper,"
    echo "    awww, etc.) may only live in the AUR."
    if ask_yes_no "Install 'paru' now?"; then
      sudo pacman -S --needed --noconfirm base-devel git
      PARU_TMP="$(mktemp -d)"
      git clone https://aur.archlinux.org/paru-bin.git "$PARU_TMP/paru-bin"
      (cd "$PARU_TMP/paru-bin" && makepkg -si --noconfirm)
      rm -rf "$PARU_TMP"
      AUR_HELPER="paru"
    else
      echo "    Continuing with official packages only; AUR ones will be reported at the end."
    fi
  fi
  echo "[✓] AUR helper: ${AUR_HELPER:-none}"
  echo

  if ask_yes_no "Run a full system update first (sudo pacman -Syu)? Recommended on an old install"; then
    sudo pacman -Syu --noconfirm
  fi
  echo

  # ---- installers ----------------------------------------------------------

  pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

  install_pkgs() {
    local repo=() aur=() p
    for p in "$@"; do
      if pkg_installed "$p"; then
        continue
      elif pacman -Si "$p" >/dev/null 2>&1; then
        repo+=("$p")
      else
        aur+=("$p")
      fi
    done

    if [ "${#repo[@]}" -gt 0 ]; then
      if ! sudo pacman -S --needed --noconfirm "${repo[@]}"; then
        echo "  [!] Batch failed; retrying one by one..."
        for p in "${repo[@]}"; do
          sudo pacman -S --needed --noconfirm "$p" || FAILED+=("$p")
        done
      fi
    fi

    if [ "${#aur[@]}" -gt 0 ]; then
      if [ -z "$AUR_HELPER" ]; then
        for p in "${aur[@]}"; do FAILED+=("$p (AUR, no helper)"); done
      else

        if ! "$AUR_HELPER" -S --needed "${aur[@]}"; then
          echo "  [!] Batch failed; retrying one by one..."
          for p in "${aur[@]}"; do
            "$AUR_HELPER" -S --needed "$p" || FAILED+=("$p")
          done
        fi
      fi
    fi
  }


  install_first() {
    local p
    for p in "$@"; do
      if pkg_installed "$p"; then return 0; fi
    done
    for p in "$@"; do
      if pacman -Si "$p" >/dev/null 2>&1; then
        if sudo pacman -S --needed --noconfirm "$p"; then return 0; fi
      elif [ -n "$AUR_HELPER" ] && "$AUR_HELPER" -Si "$p" >/dev/null 2>&1; then
        if "$AUR_HELPER" -S --needed "$p"; then return 0; fi
      fi
    done
    FAILED+=("$* (ninguna variante)")
  }

  # ---- Base ------------------------------------------------------------------

  BASE=(
    base-devel git curl unzip zip zsh jq
    hyprland hyprpaper hypridle hyprlock
    hyprpolkitagent hyprshot hyprsunset hyprshutdown hyprsysteminfo
    qt6-base qt6-declarative qt6-svg qt6-shadertools qt6ct
    pipewire pipewire-pulse wireplumber
    brightnessctl power-profiles-daemon upower
    networkmanager network-manager-applet
    playerctl bluez bluez-utils blueman
    mpv mpvpaper ffmpeg socat wl-clipboard xdg-utils
    libnotify imagemagick wtype wev grim slurp cava pavucontrol fastfetch
    matugen
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono
    ttf-silkscreen ttf-dotgothic16 ttf-vt323
  )

  echo "Installing base dependencies..."
  install_pkgs "${BASE[@]}"
  fc-cache -f >/dev/null 2>&1 || true
  echo "Installing quickshell and awww (release or -git, whichever is available)..."
  install_first quickshell quickshell-git
  install_first awww awww-git
  echo

  # --- Terminal ---
  echo "Choose your terminal:"
  select TERM_CHOICE in foot kitty alacritty wezterm ghostty "Already installed"; do
    case "$TERM_CHOICE" in
      foot|kitty|alacritty|wezterm|ghostty) install_pkgs "$TERM_CHOICE"; break ;;
      "Already installed") break ;;
      *) echo "Invalid option." ;;
    esac
  done
  echo

  # --- Servicios que OozeShell usa (nmcli, bluetoothctl, powerprofilesctl) ---
  if ask_yes_no "Enable NetworkManager, bluetooth and power-profiles-daemon services now? (skip if you use iwd/other network stack)"; then
    for svc in NetworkManager bluetooth power-profiles-daemon; do
      sudo systemctl enable --now "$svc" || FAILED+=("service:$svc")
    done
  fi
  echo

  # --- Package search ---
  echo "[i] Package search (SUPER+U) uses PacSearch (paru/pacman + AUR) on Arch; no Nix needed."
  echo "    The keybind will be switched from nixsearch to pacsearch after linking the configs."
  echo

  # --- Tools OozeShell replaces ---
  if ask_yes_no "OozeShell already integrates the bar/notifications/launcher/logout. Install swaync, waybar, swayosd, wlogout and rofi anyway, in case you want them separately?"; then
    INSTALL_LEGACY=true
    install_pkgs swaync waybar rofi wlogout swayosd
  fi
  echo

  # --- Extras ---
  if ask_yes_no "Also install the extras bundle (dev tools, gaming, misc utilities)?"; then
    EXTRAS=(
      greetd greetd-tuigreet udisks2 rtkit flatpak yazi neovim starship
      fd ripgrep dolphin nomacs gamemode lutris mangohud wine
      github-cli jdk21-openjdk lazygit python python-pip tree
      qt6-quick3d wget vim uv ruff
      bibata-cursor-theme prismlauncher protonplus protontricks
      goverlay vscodium-bin nixd nixfmt pw-viz
    )
    install_pkgs "${EXTRAS[@]}"
    echo "[i] greetd and rtkit were installed but NOT configured/enabled; set them up by hand if you want them."
  fi

  # --- Suwayomi (AUR, optional) ---
  echo
  if ask_yes_no "Install Suwayomi server (suwayomi-server-bin, AUR)?"; then
    install_pkgs suwayomi-server-bin
  fi

  # --- Nvidia (only affects env.lua) ---
  echo
  if ask_yes_no "Do you use an Nvidia GPU? (enables the Nvidia env vars in Hyprland's env.lua)"; then
    HAS_NVIDIA=true
  fi

  echo
  echo "[✓] Unzipping OozeShell-arch.zip..."
  extract_oozeshell "$ZIP_FILE"

  FC_SRC="$QS_DIR/OozeShell/tools/fonts/99-oozeshell-pixel.conf"
  if [ -f "$FC_SRC" ]; then
    mkdir -p "$HOME/.config/fontconfig/conf.d"
    cp -f "$FC_SRC" "$HOME/.config/fontconfig/conf.d/"
    fc-cache -f >/dev/null 2>&1 || true
    echo "[✓] fontconfig installed (icon fallback)"
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

  if command -v unzip >/dev/null 2>&1; then
    echo "[✓] Unzipping OozeShell.zip..."
    extract_oozeshell "$ZIP_FILE"
  else
    echo "[!] I can't find 'unzip' installed."
    if ! command -v nix-shell >/dev/null 2>&1; then
      echo "  [✗] 'nix-shell' isn't available either (not NixOS / Nix not installed)."
      echo "      Install 'unzip' with your package manager and re-run the installer."
      exit 1
    fi
    if ask_yes_no "Can I open a temporary nix-shell with unzip to extract it (installs nothing permanent)?"; then
      extract_oozeshell "$ZIP_FILE" nix
    else
      echo "  [✗] Without unzip I can't continue with this step."
      echo "      Extract OozeShell.zip by hand into $QS_DIR and re-run the installer."
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
- Nerd Fonts: "JetBrainsMono Nerd Font" and "Symbols Nerd Font Mono"
- wpctl, pw-dump, pw-link (pipewire + wireplumber)
- brightnessctl
- powerprofilesctl (power-profiles-daemon)
- upower
- nmcli (NetworkManager) + networkmanagerapplet
- playerctl
- bluetoothd (BlueZ) / Blueman
- matugen
- mpvpaper (+ mpv)
- ffmpeg
- socat
- wl-copy (wl-clipboard)
- xdg-utils (xdg-open)
- jq
- fastfetch
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

- nix-search / nix-search-cli (search runs from OozeShell's NixSearch panel)
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

greetd, udisks2, pw-viz, rtkit, flatpak, zip, unzip, yazi,
neovim, starship, fd, ripgrep, dolphin, nomacs, Adwaita-style dark
theme, Bibata-Modern-Classic cursors, gamemode, lutris, mangohud,
prismlauncher, protonplus, wine, protontricks, goverlay, curl, git, gh,
jdk21, lazygit, python3, python3Packages.pip, vscodium-fhs, nixd,
nixfmt-rfc-style, ruff, tree, qt6.qtquick3d,
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
# nix-rofi depends on nix-search: only useful on the NixOS branch
if ! $IS_ARCH; then
  create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"
fi

echo
echo "Granting execution permissions..."

scripts=(
  "$QS_DIR/OozeShell/OozeAudio/backend/audio.sh"
)

if ! $IS_ARCH; then
  scripts+=("$DOTFILES/nix-rofi")
fi

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

# ----------------------------------------------------------------------------
# Arch only: SUPER+U -> PacSearch instead of NixSearch
# ----------------------------------------------------------------------------
if $IS_ARCH; then
  KEYBINDS="$HOME/.config/hypr/modules/input/keybinds.lua"
  if [ -f "$KEYBINDS" ]; then
    cp -f "$KEYBINDS" "${KEYBINDS}.bak-${STAMP}"
    # comment the active nixsearch bind (skip if already commented)
    sed -i -E '/^hl\.bind\(mainMod \.\. " \+ U".*nixsearch toggle/ s/^/-- /' "$KEYBINDS"
    # uncomment the pacsearch bind
    sed -i -E 's/^--[[:space:]]*(hl\.bind\(mainMod \.\. " \+ U".*pacsearch toggle.*)$/\1/' "$KEYBINDS"
    echo "  [✓] keybinds.lua: SUPER+U now opens PacSearch (backup: ${KEYBINDS}.bak-${STAMP})"
  else
    echo "  [✗] keybinds.lua not found: $KEYBINDS"
  fi
  echo
fi

# ----------------------------------------------------------------------------
# Arch only: env.lua (Electron Wayland always, Nvidia vars only if requested)
# ----------------------------------------------------------------------------
if $IS_ARCH; then
  ENVLUA="$HOME/.config/hypr/modules/system/env.lua"
  if [ -f "$ENVLUA" ]; then
    cp -f "$ENVLUA" "${ENVLUA}.bak-${STAMP}"
    sed -i -E 's/^--[[:space:]]*(hl\.env\("ELECTRON_OZONE_PLATFORM_HINT", "auto"\).*)$/\1/' "$ENVLUA"
    echo "  [✓] env.lua: ELECTRON_OZONE_PLATFORM_HINT enabled"
    if $HAS_NVIDIA; then
      sed -i -E 's/^--[[:space:]]*(hl\.env\("LIBVA_DRIVER_NAME", "nvidia"\).*)$/\1/' "$ENVLUA"
      sed -i -E 's/^--[[:space:]]*(hl\.env\("__GLX_VENDOR_LIBRARY_NAME", "nvidia"\).*)$/\1/' "$ENVLUA"
      echo "  [✓] env.lua: Nvidia variables enabled (LIBVA_DRIVER_NAME, __GLX_VENDOR_LIBRARY_NAME)"
    fi
    echo "      Backup: ${ENVLUA}.bak-${STAMP}"
  else
    echo "  [✗] env.lua not found: $ENVLUA"
  fi
  echo
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "=========================================="
  echo "  [!] These packages/services were NOT installed:"
  for f in "${FAILED[@]}"; do echo "      - $f"; done
  echo "  Check the names with: pacman -Ss <name>  /  ${AUR_HELPER:-paru} -Ss <name>"
  echo "=========================================="
  echo
fi

echo "=========================================="
echo "       Oozenix installation complete!"
echo "=========================================="
if $IS_ARCH; then
  echo "Start it with:  quickshell -c OozeShell"
fi