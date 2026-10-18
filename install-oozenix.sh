#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$HOME/dotfiles"
NIXOS_MD="$DOTFILES/NixOSInstallation.md"
QS_DIR="$DOTFILES/.config/quickshell"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/backups"

INSTALL_LEGACY=false
IS_ARCH=false
IS_UPDATE=false
HAS_NVIDIA=false
SUWAYOMI_OK=false
NATIVE_OK=false
OOZEWALLS_OK=false
NATIVE_PREFIX="$HOME/.local/share/oozeshell/qml"
AUR_HELPER=""
FAILED=()

# ── Helpers ──
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

# OozeShell cambió de layout: tools/ pasó a Tools/ y OozeAudio/ + PackageSearch/
# pasaron a Services/…  Se resuelven al usarlas (después de extraer el zip) para
# seguir aceptando tanto zips nuevos como antiguos.
oozeshell_tools() {
  if [ -d "$QS_DIR/OozeShell/Tools" ]; then
    printf '%s\n' "$QS_DIR/OozeShell/Tools"
  else
    printf '%s\n' "$QS_DIR/OozeShell/tools"
  fi
}

oozeshell_services() {
  if [ -d "$QS_DIR/OozeShell/Services" ]; then
    printf '%s\n' "$QS_DIR/OozeShell/Services"
  else
    printf '%s\n' "$QS_DIR/OozeShell"
  fi
}

extract_oozeshell() {
  local zip="$1" runner="${2:-}"
  mkdir -p "$QS_DIR"
  if [ -d "$QS_DIR/OozeShell" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$QS_DIR/OozeShell" "$BACKUP_DIR/OozeShell.bak-${STAMP}"
    echo "  [✓] Previous OozeShell moved to $BACKUP_DIR/OozeShell.bak-${STAMP}"
  fi
  if [ "$runner" = "nix" ]; then
    nix-shell -p unzip --run "unzip -qo '$zip' -d '$QS_DIR'"
  else
    unzip -qo "$zip" -d "$QS_DIR"
  fi
  rm -rf "$QS_DIR/OozeShell/native/AnimationController/build"
}

build_native() {
  local runner="${1:-}"
  local script="$(oozeshell_tools)/build-native.sh"
  local shellnix="$QS_DIR/OozeShell/native/shell.nix"
  local ok=false

  if [ ! -f "$script" ]; then
    echo "  [i] This OozeShell build has no native module; skipping."
    return 0
  fi
  if [ -d "$NATIVE_PREFIX/OozeShell/Native" ]; then
    echo "  [i] Native core already built: rebuilding it against your current Qt."
  fi

  if [ "$runner" = "nix" ]; then
    nix-shell "$shellnix" --run "bash '$script' '$NATIVE_PREFIX'" && ok=true
  else
    bash "$script" "$NATIVE_PREFIX" && ok=true
  fi

  if $ok; then
    NATIVE_OK=true
    echo "  [✓] Native core installed in $NATIVE_PREFIX/OozeShell/Native"
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local excl
      excl="$(git -C "$DOTFILES" rev-parse --git-path info/exclude)"
      mkdir -p "$(dirname "$excl")"
      grep -qxF ".config/quickshell/OozeShell/native/AnimationController/build/" "$excl" 2>/dev/null \
        || echo ".config/quickshell/OozeShell/native/AnimationController/build/" >> "$excl"
    fi
  else
    echo "  [!] The native core did not build. OozeShell still works in pure QML."
    if [ "$runner" = "nix" ]; then
      echo "      On NixOS the Qt in native/shell.nix must be the SAME one quickshell uses"
      echo "      (see the header of native/shell.nix). Retry later with:"
      echo "        nix-shell $shellnix --run 'bash $script'"
    else
      echo "      Retry later with:  bash $script"
    fi
  fi
  return 0
}

maybe_build_native_other() {
  local runner=""
  if [ ! -f "$(oozeshell_tools)/build-native.sh" ]; then return 0; fi
  if command -v nix-shell >/dev/null 2>&1; then
    runner="nix"
  elif ! command -v cmake >/dev/null 2>&1; then
    echo "[i] Optional native core skipped (no nix-shell and no cmake)."
    return 0
  fi
  echo
  if ask_yes_no "Build the optional native animation core (C++, ~1 min)? OozeShell works without it"; then
    build_native "$runner"
  fi
}

install_oozewalls() {
  local dir="$DOTFILES/OozeWalls" ok=false
  if [ ! -f "$dir/Cargo.toml" ]; then
    echo "  [i] OozeWalls source not found in $dir; skipping."
    return 0
  fi
  echo
  if ! ask_yes_no "Build and install the OozeWalls engine (Rust, a few minutes)? Optional: pick it in Settings -> Wallpapers"; then
    return 0
  fi
  chmod +x "$dir/install.sh"

  if $IS_ARCH; then
    install_pkgs wayland libxkbcommon mesa libglvnd fontconfig freetype2 \
      libx11 libxcursor libxrandr libxi xdg-desktop-portal xdg-desktop-portal-gtk
    if ! command -v cargo >/dev/null 2>&1; then
      install_pkgs rust
    fi
  fi

  if command -v cargo >/dev/null 2>&1; then
    bash "$dir/install.sh" && ok=true
  elif command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p cargo rustc gcc pkg-config --run "bash '$dir/install.sh'" && ok=true
  else
    echo "  [!] cargo not found and no nix-shell available; cannot build OozeWalls."
  fi

  if $ok; then
    OOZEWALLS_OK=true
    echo "  [✓] OozeWalls installed: $HOME/.local/bin/oozewalls"
  else
    echo "  [!] OozeWalls did not build. Retry later with:  bash $dir/install.sh"
    FAILED+=("oozewalls (build)")
  fi
  return 0
}

# ── Pre-checks ──
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
if [ -L "$HOME/.config/hypr" ] && [ "$(readlink "$HOME/.config/hypr")" = "$DOTFILES/.config/hypr" ]; then
  IS_UPDATE=true
  echo "[i] Existing install detected: running in update mode."
fi
echo

# ── Distro selection ──
if ask_yes_no "Are you using Arch Linux?"; then
  IS_ARCH=true
  if [ ! -f /etc/arch-release ] || ! command -v pacman >/dev/null 2>&1; then
    echo "[!] This doesn't look like Arch (no /etc/arch-release or no pacman)."
    ask_yes_no "    Continue with the Arch branch anyway?" || exit 1
  fi
fi

# ── OozeShell.zip ──
ZIP_FILE="$DOTFILES/OozeShell.zip"
if [ ! -f "$ZIP_FILE" ]; then
  echo "[✗] Could not find $ZIP_FILE"
  echo "    Put it there and re-run the installer."
  exit 1
fi
echo "[✓] Found $(basename "$ZIP_FILE")"

# ── Arch branch ──
if $IS_ARCH; then
  echo
  echo "── Arch Linux ────────────────────────────────────────────────"

  # ── AUR helper ──
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

  # ── Package helpers ──
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

  check_hyprland() {
    local ver
    ver="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')"
    ver="${ver#*:}"
    ver="${ver%%-*}"
    [ -n "$ver" ] || return 0
    if [ "$(printf '%s\n%s\n' "0.55.0" "$ver" | sort -V | head -n1)" != "0.55.0" ]; then
      echo "  [!] hyprland $ver is older than 0.55: the Lua config (hyprland.lua) needs 0.55 or newer."
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
    FAILED+=("$* (no variant could be installed)")
  }

  # ── Suwayomi helpers ──
  SUWAYOMI_MD="$DOTFILES/SuwayomiSetup.md"
  TACHIDESK_CTL_SYS="/usr/local/bin/tachidesk"
  TACHIDESK_CTL_USER="$HOME/.local/bin/tachidesk"
  TACHIDESK_UNIT="$HOME/.config/systemd/user/tachidesk.service"

  find_suwayomi_bin() {
    local b f pkg
    for b in tachidesk-server suwayomi-server; do
      if command -v "$b" >/dev/null 2>&1; then command -v "$b"; return 0; fi
    done
    for pkg in suwayomi-server-bin suwayomi-server-preview-bin tachidesk; do
      pacman -Qq "$pkg" >/dev/null 2>&1 || continue
      f="$(pacman -Ql "$pkg" 2>/dev/null | awk '{print $2}' \
            | grep -E '^/usr/bin/[^/]+$' | grep -Ei 'suwayomi|tachidesk' | head -n1 || true)"
      if [ -n "$f" ]; then echo "$f"; return 0; fi
    done
    return 1
  }

  tachidesk_ctl_body() {
    cat << 'EOF'
#!/usr/bin/env bash
case "$1" in
  start|stop|restart|enable|disable) systemctl --user "$1" tachidesk.service ;;
  status) systemctl --user status tachidesk.service --no-pager ;;
  *) echo "Usage: tachidesk {start|stop|restart|status|enable|disable}"; exit 1 ;;
esac
EOF
  }

  tachidesk_unit_body() {
    cat << EOF
[Unit]
Description=Tachidesk Server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$1
WorkingDirectory=%h/.local/share/Tachidesk
Environment=HOME=%h
Restart=on-failure
RestartSec=5
TimeoutStopSec=15
KillSignal=SIGTERM

[Install]
WantedBy=default.target
EOF
  }

  write_suwayomi_md() {
    {
      cat << 'MDEOF'
# Suwayomi server on Arch (manual setup)

The installer skipped Suwayomi. These are the steps to install it later and
control it like a service, with the same `tachidesk` command used on NixOS.
OozeShell (Settings -> Services) uses that command, so once it is in place you
can start/stop the server from the shell.

## 1. Install the package (AUR)

```bash
paru -S suwayomi-server-bin      # or: yay -S suwayomi-server-bin
```

It needs a Java runtime >= 21 (`sudo pacman -S jre21-openjdk` if you have none).

## 2. Find the executable name

```bash
pacman -Ql suwayomi-server-bin | grep 'bin/'
```

It is probably `/usr/bin/tachidesk-server` or `/usr/bin/suwayomi-server`.
Use that path as `ExecStart` in step 4.

## 3. Create the directories

```bash
mkdir -p ~/.local/share/Tachidesk/extensions ~/.local/share/Tachidesk/backups
mkdir -p ~/Manga/Downloads ~/.config/systemd/user
```

## 4. Create the user service

File: `~/.config/systemd/user/tachidesk.service`

```ini
[Unit]
Description=Tachidesk Server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/tachidesk-server
WorkingDirectory=%h/.local/share/Tachidesk
Environment=HOME=%h
Restart=on-failure
RestartSec=5
TimeoutStopSec=15
KillSignal=SIGTERM

[Install]
WantedBy=default.target
```

## 5. Create the `tachidesk` control command

Put it in `/usr/local/bin` (NOT only in `~/.local/bin`): OozeShell runs the
command with its own PATH, and a Hyprland session usually does not include
`~/.local/bin`.

File: `/usr/local/bin/tachidesk`

```bash
MDEOF
      tachidesk_ctl_body
      cat << 'MDEOF'
```

```bash
sudo install -Dm755 tachidesk /usr/local/bin/tachidesk   # from the file above
systemctl --user daemon-reload
```

## 6. Use it

From OozeShell: Settings -> Services, or from a terminal:

```bash
tachidesk start
tachidesk status
tachidesk stop
```

The service is not enabled at boot. Run `tachidesk enable` if you want that.
If Suwayomi is already running by hand, stop it first with
`pkill -TERM -f -i suwayomi`, or the port (4567) will be busy.
MDEOF
    } > "$SUWAYOMI_MD"
    echo "[✓] Steps saved to: $SUWAYOMI_MD"
  }

  install_tachidesk_ctl() {
    local tmp
    tmp="$(mktemp)"
    tachidesk_ctl_body > "$tmp"
    chmod +x "$tmp"

    if [ -e "$TACHIDESK_CTL_SYS" ] && ! cmp -s "$tmp" "$TACHIDESK_CTL_SYS"; then
      sudo cp -f "$TACHIDESK_CTL_SYS" "${TACHIDESK_CTL_SYS}.bak-${STAMP}" || true
    fi

    if sudo install -Dm755 "$tmp" "$TACHIDESK_CTL_SYS"; then
      echo "  [✓] Control command: $TACHIDESK_CTL_SYS  (tachidesk start|stop|restart|status|enable|disable)"
      if [ -f "$TACHIDESK_CTL_USER" ] && [ ! -L "$TACHIDESK_CTL_USER" ]; then
        mv -f "$TACHIDESK_CTL_USER" "${TACHIDESK_CTL_USER}.bak-${STAMP}"
        echo "  [i] Old copy moved to ${TACHIDESK_CTL_USER}.bak-${STAMP}"
      fi
    else
      echo "  [!] Could not write to $TACHIDESK_CTL_SYS (sudo failed); using ~/.local/bin instead."
      mkdir -p "$(dirname "$TACHIDESK_CTL_USER")"
      if [ -e "$TACHIDESK_CTL_USER" ]; then cp -f "$TACHIDESK_CTL_USER" "${TACHIDESK_CTL_USER}.bak-${STAMP}"; fi
      install -m755 "$tmp" "$TACHIDESK_CTL_USER"
      echo "  [✓] Control command: $TACHIDESK_CTL_USER"
      echo "  [!] OozeShell only finds it if ~/.local/bin is in the PATH of your Hyprland session."
      echo "      Otherwise the Services page will not be able to control the server."
    fi
    rm -f "$tmp"
  }

  setup_suwayomi() {
    local bin

    if ! bin="$(find_suwayomi_bin)"; then
      echo "  [!] Could not find the Suwayomi executable; skipping the service setup."
      write_suwayomi_md
      return 0
    fi
    echo "  [✓] Suwayomi executable: $bin"

    mkdir -p "$HOME/.local/share/Tachidesk/extensions" "$HOME/.local/share/Tachidesk/backups" \
             "$HOME/Manga/Downloads" "$HOME/.config/systemd/user"

    if [ -e "$TACHIDESK_UNIT" ]; then cp -f "$TACHIDESK_UNIT" "${TACHIDESK_UNIT}.bak-${STAMP}"; fi
    tachidesk_unit_body "$bin" > "$TACHIDESK_UNIT"
    echo "  [✓] User service: $TACHIDESK_UNIT"

    install_tachidesk_ctl

    if systemctl --user daemon-reload 2>/dev/null; then
      if systemctl --user cat tachidesk.service >/dev/null 2>&1; then
        echo "  [✓] systemd sees tachidesk.service"
        SUWAYOMI_OK=true
      else
        echo "  [!] systemd did not load tachidesk.service; check: systemctl --user cat tachidesk.service"
      fi
    else
      echo "  [!] Could not reload the user systemd session; run 'systemctl --user daemon-reload' after logging in."
      SUWAYOMI_OK=true
    fi

    if ! systemctl --user is-active --quiet tachidesk.service 2>/dev/null \
       && pgrep -f -i 'java.*(suwayomi|tachidesk)' >/dev/null 2>&1; then
      echo "  [!] A Suwayomi process is already running (started by hand?)."
      echo "      Stop it before using the service, or the port will be busy:"
      echo "        pkill -TERM -f -i suwayomi"
    fi

    echo "  [i] Not started or enabled on boot (same as NixOS)."
    echo "      Control it from OozeShell (Settings -> Services) or with: tachidesk start"
    if ask_yes_no "  Start Tachidesk now?"; then
      tachidesk start || echo "  [!] 'tachidesk start' failed; see: tachidesk status"
      sleep 2
      tachidesk status 2>&1 | sed -n '1,6p' || true
    fi
  }

  # ── Base packages ──
  BASE=(
    base-devel git curl unzip zip zsh jq python
    hyprland hyprpaper hypridle hyprlock
    hyprpolkitagent hyprshot hyprsunset hyprshutdown hyprsysteminfo
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt6-base qt6-declarative qt6-svg qt6-shadertools qt6ct
    pipewire pipewire-pulse wireplumber
    brightnessctl power-profiles-daemon upower
    networkmanager network-manager-applet
    playerctl bluez bluez-utils blueman
    mpv mpvpaper ffmpeg socat xdg-utils
    libnotify imagemagick wtype wev grim slurp cava pavucontrol fastfetch
    qpwgraph rofi tmux
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
  check_hyprland
  echo

  # ── Clipboard tools ──
  echo "Installing clipboard tools (wl-clipboard + cliphist)..."
  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    echo "  [✓] wl-copy / wl-paste already available"
  else
    install_first wl-clipboard wl-clipboard-rs
  fi
  if command -v cliphist >/dev/null 2>&1; then
    echo "  [✓] cliphist already available"
  else
    install_first cliphist cliphist-git
  fi
  for c in wl-copy wl-paste cliphist; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "  [!] '$c' is still missing: the clipboard history panel will show its 'missing dependencies' notice."
      FAILED+=("clipboard: $c")
    fi
  done
  echo

  # ── Terminal ──
  echo "Choose your terminal:"
  select TERM_CHOICE in foot kitty alacritty wezterm ghostty "Already installed"; do
    case "$TERM_CHOICE" in
      foot|kitty|alacritty|wezterm|ghostty) install_pkgs "$TERM_CHOICE"; break ;;
      "Already installed") break ;;
      *) echo "Invalid option." ;;
    esac
  done
  echo

  # ── Services ──
  if ask_yes_no "Enable NetworkManager, bluetooth and power-profiles-daemon services now? (skip if you use iwd/other network stack)"; then
    for svc in NetworkManager bluetooth power-profiles-daemon; do
      sudo systemctl enable --now "$svc" || FAILED+=("service:$svc")
    done
  fi
  echo

  echo "[i] Package search (SUPER+U): OozeShell detects Arch on its own and searches with"
  echo "    paru/yay/pacman + AUR (no Nix needed). The keybind stays on 'nixsearch' (IPC name)."
  echo

  # ── Optional packages ──
  if ask_yes_no "Install Waybar? It is an optional bar backend you can pick inside OozeShell (Settings -> Bar)"; then
    install_pkgs waybar
  fi
  echo
  if ask_yes_no "Also install swaync, swayosd and wlogout? OozeShell already replaces them; only needed if you want them separately"; then
    INSTALL_LEGACY=true
    install_pkgs swaync swayosd wlogout
  fi
  echo

  # ── Extras ──
  if ask_yes_no "Also install the extras bundle (dev tools, gaming, misc utilities)?"; then
    EXTRAS=(
      greetd greetd-tuigreet udisks2 rtkit flatpak yazi neovim starship
      fd ripgrep dolphin nomacs gamemode lutris mangohud wine
      github-cli jdk21-openjdk lazygit python-pip tree
      qt6-quick3d wget vim uv ruff
      bibata-cursor-theme prismlauncher protonplus protontricks
      goverlay vscodium-bin nixd nixfmt pw-viz
    )
    install_pkgs "${EXTRAS[@]}"
    echo "[i] greetd and rtkit were installed but NOT configured/enabled; set them up by hand if you want them."
  fi

  echo
  # ── Suwayomi ──
  if ask_yes_no "Install Suwayomi server (suwayomi-server-bin, AUR) and control it from OozeShell (same as on NixOS)?"; then
    install_first jre21-openjdk jdk21-openjdk jdk-openjdk jre-openjdk
    install_pkgs suwayomi-server-bin
    setup_suwayomi
  else
    echo "[i] Skipping Suwayomi. Writing the manual steps for later..."
    write_suwayomi_md
  fi

  echo
  # ── Nvidia ──
  if ask_yes_no "Do you use an Nvidia GPU? (enables the Nvidia env vars in Hyprland's env.lua)"; then
    HAS_NVIDIA=true
  fi

  echo
  echo "[✓] Unzipping OozeShell.zip..."
  extract_oozeshell "$ZIP_FILE"

  # ── Fonts ──
  FC_SRC="$(oozeshell_tools)/fonts/99-oozeshell-pixel.conf"
  if [ -f "$FC_SRC" ]; then
    mkdir -p "$HOME/.config/fontconfig/conf.d"
    cp -f "$FC_SRC" "$HOME/.config/fontconfig/conf.d/"
    fc-cache -f >/dev/null 2>&1 || true
    echo "[✓] fontconfig installed (icon fallback)"
  fi

  # ── Native core ──
  if [ -f "$(oozeshell_tools)/build-native.sh" ]; then
    echo
    if ask_yes_no "Build the optional native animation core (C++, needs cmake, ~1 min)? OozeShell works without it"; then
      install_pkgs cmake
      if command -v cmake >/dev/null 2>&1; then
        build_native
      else
        echo "  [!] cmake is missing; skipping the native core."
      fi
    fi
  fi

# ── Non-Arch branch ──
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

  maybe_build_native_other

  echo
  if ask_yes_no "Link the swaync and swayosd configs? OozeShell already replaces them; only needed if you want them separately"; then
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
- tmux (Launcher tmux sessions)
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
- wl-copy / wl-paste (wl-clipboard)
- cliphist (clipboard history panel; needs wl-clipboard too)
- xdg-utils (xdg-open)
- jq
- python3 >= 3.11 (palette-apply.py: applies the fixed Palettes to the matugen
  templates, i.e. terminals, Hyprland, Qt/KDE, etc.)
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
- Optional, GPU stats: nvidia-smi (NVIDIA) or the amdgpu sysfs counters
- Optional, to-do alarm sound: pw-play or paplay (pipewire / libpulse)

## Optional — native animation core (C++)

OozeShell ships a small C++ module (`OozeShell.Native`). Without it everything
still works in pure QML; with it the animation maths run natively.

- Build tools: cmake >= 3.21, a C++17 compiler, Qt6 qtbase + qtdeclarative
  (with dev headers). On NixOS use the provided shell:

```bash
nix-shell ~/.config/quickshell/OozeShell/native/shell.nix \
  --run 'bash ~/.config/quickshell/OozeShell/Tools/build-native.sh'
```

- The Qt used to build MUST be the same one your `quickshell` uses, or Qt
  rejects the plugin (details in `native/shell.nix`).
- Quickshell must be told where the module lives (once, in the Hyprland
  session environment; the installer adds it to `env.lua` when the build works):

```lua
hl.env("QML_IMPORT_PATH", os.getenv("HOME") .. "/.local/share/oozeshell/qml")
```

- On start OozeShell logs `[theme] núcleo nativo: activo` (or the reason it
  is not available).

## Optional — OozeWalls engine

- cargo + rustc + gcc (the installer builds `~/dotfiles/OozeWalls` and copies
  `oozewalls` and `oozewalls-gui` to `~/.local/bin`)
- Runtime: wayland, libxkbcommon, mesa/libglvnd (GL/EGL), fontconfig, freetype,
  libX11, libXcursor, libXrandr, libXi
- xdg-desktop-portal (+ a FileChooser backend such as xdg-desktop-portal-gtk)
  for the folder picker in the app
- mpvpaper + mpv + socat for live wallpapers

## Optional — NixSearch

- nix-search / nix-search-cli (search runs from OozeShell's NixSearch panel)
- nix (nix shell / nix profile install from NixSearch)

If not installed, the rest of OozeShell still works.

## Optional — alternative bar

- waybar: bar backend selectable in OozeShell (Settings -> Bar). Its config
  is always linked; only the package is optional.

## Optional — other compositors

- niri or mango (mmsg): OozeShell detects them on its own.

## Optional — tools OozeShell replaces

No longer needed for normal use (notifications, launcher, logout are already
integrated into OozeShell), but the configs stay in the dotfiles in case you
want to use them separately:

- swaync
- swayosd
- wlogout

Rofi is NOT in that list anymore: it is a first-class backend option
(Advanced Settings → Launcher / PowerMenu) and its config always installs.

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

echo
# ── Symlinks and permissions ──
echo "=========================================="
echo "     Creating symlinks and permissions"
echo "=========================================="
echo

mkdir -p "$HOME/.config" "$HOME/.local/bin"

echo "Creating .config symlinks..."

config_items=(
  "alacritty"
  "cava"
  "dolphin"
  "fastfetch"
  "foot"
  "ghostty"
  "hypr"
  "kitty"
  "matugen"
  "nvim"
  "quickshell"
  "rofi"
  "wezterm"
  "yazi"
  "waybar"
  "starship.toml"
)

if $INSTALL_LEGACY; then
  config_items+=("swaync" "swayosd")
fi

for wm in niri mango; do
  if [ -e "$DOTFILES/.config/$wm" ]; then config_items+=("$wm"); fi
done

for item in "${config_items[@]}"; do
  create_symlink "$DOTFILES/.config/$item" "$HOME/.config/$item"
done

create_symlink "$DOTFILES/.config/VK-Th/themes" "$HOME/.config/vesktop/themes"

echo
echo "Creating home & binary symlinks..."

create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES/random-fastfetch" "$HOME/.local/bin/random-fastfetch"
if ! $IS_ARCH; then
  create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"
fi

echo
echo "Granting execution permissions..."

scripts=(
  "$(oozeshell_services)/OozeAudio/backend/audio.sh"
  "$(oozeshell_services)/PackageSearch/installed.sh"
  "$(oozeshell_tools)/build-native.sh"
  "$(oozeshell_tools)/live-optimize.sh"
  "$(oozeshell_tools)/check.sh"
  "$(oozeshell_tools)/palette-apply.py"
  "$(oozeshell_tools)/oozeshell"
  "$DOTFILES/random-fastfetch"
  "$DOTFILES/OozeWalls/install.sh"
  "$DOTFILES/.config/rofi/Launcher/launcher.sh"
  "$DOTFILES/.config/rofi/Powermenu/powermenu.sh"
  "$DOTFILES/.config/rofi/Bluetooth/bluetooth.sh"
  "$DOTFILES/.config/dolphin/apply.sh"
  "$DOTFILES/.config/waybar/waybar-launcher.sh"
  "$DOTFILES/.config/waybar/scripts/notify-state.sh"
  "$DOTFILES/.config/waybar/themes/waybar-theme-switcher.sh"
  "$DOTFILES/.config/matugen/scripts/reload-waybar.sh"
)

if ! $IS_ARCH; then
  scripts+=("$DOTFILES/nix-rofi")
fi

for script in "${scripts[@]}"; do
  if [ -f "$script" ]; then
    chmod +x "$script"
    echo "  [✓] Executable: $script"
  else
    echo "  [✗] Script file not found: $script"
  fi
done

# ── Keybinds: migrate legacy IPC calls ──
# Old dotfiles can still call IPC targets/paths that no longer exist:
#   - "pacsearch"                      -> "nixsearch" (it detects Arch by itself)
#   - .../OozeShell-mango/shell.qml    -> .../OozeShell/shell.qml
#   - /home/<user>/...OozeShell call apps ...   (hardcoded home, no shell.qml, no "--")
#       -> ~/.config/quickshell/OozeShell/shell.qml call -- apps ...
#   - niri 'spawn "qs ipc ..."' / mango ',spawn,qs ipc ...' -> spawn-sh / spawn_shell
#     (plain spawn runs no shell, so ~ is never expanded)
migrate_ipc_binds() {
  local f
  for f in \
    "$HOME/.config/hypr/modules/input/keybinds.lua" \
    "$HOME/.config/hypr/modules/startup/programs.lua" \
    "$HOME/.config/niri/modules/binds.kdl" \
    "$HOME/.config/mango/conf/keybinds.conf"; do
    [ -f "$f" ] || continue
    if grep -qE 'pacsearch|OozeShell-mango|OozeShell call apps|spawn "(qs|quickshell) ipc|,spawn,(qs|quickshell) ipc' "$f"; then
      cp -f "$f" "${f}.bak-${STAMP}"
      sed -i -E \
        -e 's/(call( --)? )pacsearch /\1nixsearch /' \
        -e 's#spawn "(qs|quickshell) ipc#spawn-sh "\1 ipc#' \
        -e 's#,spawn,(qs|quickshell) ipc#,spawn_shell,\1 ipc#' \
        -e 's#OozeShell-mango/shell\.qml#OozeShell/shell.qml#g' \
        -e 's#(qs|quickshell) ipc -p (/home/[^/ ]+|~|\$HOME)/\.config/quickshell/OozeShell call (--[[:space:]]+)?apps #quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- apps #g' \
        "$f"
      echo "  [✓] IPC calls updated in $f (backup: ${f}.bak-${STAMP})"
    fi
  done
}
migrate_ipc_binds
echo

# ── oozeshell: short launcher for the IPC (oozeshell apps open browser) ──
OOZESHELL_TOOL="$(oozeshell_tools)/oozeshell"
if [ -f "$OOZESHELL_TOOL" ]; then
  chmod +x "$OOZESHELL_TOOL"
  create_symlink "$OOZESHELL_TOOL" "$HOME/.local/bin/oozeshell"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  [!] ~/.local/bin is not in PATH; add it to use 'oozeshell' from a terminal." ;;
  esac
  echo
fi

# ── OozeWalls engine ──
install_oozewalls
echo

# ── Arch: env.lua ──
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

# ── Native core: QML_IMPORT_PATH ──
if $NATIVE_OK; then
  ENVLUA="$HOME/.config/hypr/modules/system/env.lua"
  QML_LINE='hl.env("QML_IMPORT_PATH", os.getenv("HOME") .. "/.local/share/oozeshell/qml")'
  if [ -f "$ENVLUA" ]; then
    if grep -q 'QML_IMPORT_PATH' "$ENVLUA"; then
      echo "  [✓] env.lua already sets QML_IMPORT_PATH"
    else
      [ -f "${ENVLUA}.bak-${STAMP}" ] || cp -f "$ENVLUA" "${ENVLUA}.bak-${STAMP}"
      printf '\n-- OozeShell native core (added by install-oozenix.sh)\n%s\n' "$QML_LINE" >> "$ENVLUA"
      echo "  [✓] env.lua: QML_IMPORT_PATH added (log out and back in to apply)"
    fi
  else
    echo "  [!] env.lua not found: $ENVLUA"
    echo "      Add this to your Hyprland session environment by hand:"
    echo "        $QML_LINE"
  fi
  echo
fi

# ── Update mode: generated files ──
if $IS_UPDATE && git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  AUTOGEN_REL=".config/hypr/modules/appearance/autogen"
  if [ -n "$(git -C "$DOTFILES" ls-files "$AUTOGEN_REL")" ]; then
    git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL" \
      | xargs -0 git -C "$DOTFILES" update-index --skip-worktree
    EXCL="$(git -C "$DOTFILES" rev-parse --git-path info/exclude)"
    mkdir -p "$(dirname "$EXCL")"
    grep -qxF "$AUTOGEN_REL/" "$EXCL" 2>/dev/null || echo "$AUTOGEN_REL/" >> "$EXCL"
    echo "  [✓] Git now ignores local changes in $AUTOGEN_REL (generated by OozeShell)"
    echo "      Undo: git -C ~/dotfiles ls-files -z $AUTOGEN_REL | xargs -0 git -C ~/dotfiles update-index --no-skip-worktree"
    echo
  fi
fi

# ── Summary ──
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
echo "Start it with:  quickshell -c OozeShell"
echo "IPC:            oozeshell list   (targets/functions)  ·  oozeshell apps open browser"
if ! command -v waybar >/dev/null 2>&1; then
  echo "Waybar:         not installed; the Waybar option in Settings -> Bar stays disabled until you install it"
fi
if $NATIVE_OK; then
  echo "Native core:    log out and back in once (QML_IMPORT_PATH); the log should say"
  echo "                '[theme] núcleo nativo: activo'"
fi
if $OOZEWALLS_OK; then
  echo "OozeWalls:      Settings -> Wallpapers -> engine OozeWalls  ·  oozewalls status --json  ·  launcher: OozeWalls"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "                ~/.local/bin is not in your session PATH; the shell adds it itself, a terminal may need it" ;;
  esac
fi
if $IS_ARCH && $SUWAYOMI_OK; then
  echo "Tachidesk:      OozeShell -> Settings -> Services, or:  tachidesk start|stop|restart|status|enable|disable"
fi
if ! $IS_ARCH; then
  echo "Dependencies:   see $NIXOS_MD"
fi