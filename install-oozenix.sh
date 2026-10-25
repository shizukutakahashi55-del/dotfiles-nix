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

ASSUME_YES=false
ARCH_DETECTED=false
ZIP_FILE="$DOTFILES/OozeShell.zip"
TERM_SKIP="I already have one"
TERM_CHOICE="$TERM_SKIP"
CONFLICT_POLICY="ask"
OPT_PARU=false
OPT_UPDATE=false
OPT_SERVICES=false
OPT_WAYBAR=false
OPT_EXTRAS=false
OPT_SUWAYOMI=false
OPT_SUWAYOMI_START=false
OPT_NATIVE=false
OPT_OOZEWALLS=false
SUDO_PID=""

# ── UI ──
UI_COLOR=false
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  UI_COLOR=true
fi

if $UI_COLOR; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

UI_WIDTH="$(tput cols 2>/dev/null || echo 70)"
if [ "$UI_WIDTH" -gt 76 ]; then UI_WIDTH=76; fi
if [ "$UI_WIDTH" -lt 50 ]; then UI_WIDTH=50; fi

UI_STEP=0
WIZ_INDEX=0
WIZ_TOTAL=0

ui_repeat() {
  local i out=""
  for ((i = 0; i < $2; i++)); do out+="$1"; done
  printf '%s' "$out"
}

ui_banner_row() {
  local text="$1" style="$2" inner=$((UI_WIDTH - 2)) left right
  left=$(((inner - ${#text}) / 2))
  if [ "$left" -lt 0 ]; then left=0; fi
  right=$((inner - ${#text} - left))
  if [ "$right" -lt 0 ]; then right=0; fi
  printf '%s│%s%*s%s%s%s%*s%s│%s\n' \
    "$C_CYAN" "$C_RESET" "$left" "" "$style" "$text" "$C_RESET" "$right" "" "$C_CYAN" "$C_RESET"
}

ui_banner() {
  local inner=$((UI_WIDTH - 2))
  printf '\n%s╭%s╮%s\n' "$C_CYAN" "$(ui_repeat '─' "$inner")" "$C_RESET"
  ui_banner_row "$1" "$C_BOLD"
  if [ -n "${2:-}" ]; then ui_banner_row "$2" "$C_DIM"; fi
  printf '%s╰%s╯%s\n' "$C_CYAN" "$(ui_repeat '─' "$inner")" "$C_RESET"
}

ui_phase() {
  printf '\n%s%s══ %s %s%s\n' "$C_BOLD" "$C_BLUE" "$1" "$(ui_repeat '═' $((UI_WIDTH - ${#1} - 4)))" "$C_RESET"
}

ui_wizard_section() {
  WIZ_INDEX=$((WIZ_INDEX + 1))
  printf '\n%s%s━━ %s/%s · %s %s%s\n' \
    "$C_BOLD" "$C_CYAN" "$WIZ_INDEX" "$WIZ_TOTAL" "$1" "$(ui_repeat '━' $((UI_WIDTH - ${#1} - 12)))" "$C_RESET"
}

ui_step() {
  UI_STEP=$((UI_STEP + 1))
  printf '\n%s%s▶ Step %s · %s%s\n' "$C_BOLD" "$C_CYAN" "$UI_STEP" "$1" "$C_RESET"
}

ui_intro() {
  local line
  for line in "$@"; do
    printf '  %s%s%s\n' "$C_DIM" "$line" "$C_RESET"
  done
}

ui_task() { printf '  %s•%s %s\n' "$C_BLUE" "$C_RESET" "$1"; }
ui_ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
ui_warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
ui_err() { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; }
ui_info() { printf '  %si%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; }

ui_yn() {
  if "$1"; then printf 'yes'; else printf 'no'; fi
}

ui_row() {
  local style="$C_RESET"
  case "$2" in
    yes) style="$C_GREEN" ;;
    no) style="$C_DIM" ;;
  esac
  printf '    %-32s %s%s%s\n' "$1" "$style" "$2" "$C_RESET"
}

# ── Helpers ──
ask_yes_no() {
  local title="$1" def="$2" hint reply line
  shift 2
  printf '\n  %s?%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  for line in "$@"; do
    printf '    %s%s%s\n' "$C_DIM" "$line" "$C_RESET"
  done
  if [ "$def" = "y" ]; then hint="Y/n"; else hint="y/N"; fi
  if $ASSUME_YES; then
    printf '    %s› auto-answer: %s%s\n' "$C_YELLOW" "$def" "$C_RESET"
    if [ "$def" = "y" ]; then return 0; else return 1; fi
  fi
  while true; do
    read -r -p "    ${C_YELLOW}›${C_RESET} [$hint] " reply || { echo; return 1; }
    case "${reply,,}" in
      "") if [ "$def" = "y" ]; then return 0; else return 1; fi ;;
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) ui_warn "Please answer y or n." ;;
    esac
  done
}

ask_choice() {
  local var="$1" title="$2" def="$3" reply i marker line
  local help=() options=()
  shift 3
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    help+=("$1")
    shift
  done
  if [ "$#" -gt 0 ]; then shift; fi
  options=("$@")

  printf '\n  %s?%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  for line in "${help[@]}"; do
    printf '    %s%s%s\n' "$C_DIM" "$line" "$C_RESET"
  done
  for ((i = 0; i < ${#options[@]}; i++)); do
    marker=""
    if [ "$((i + 1))" -eq "$def" ]; then marker=" ${C_DIM}(suggested)${C_RESET}"; fi
    printf '    %s%d)%s %s%s\n' "$C_YELLOW" "$((i + 1))" "$C_RESET" "${options[$i]}" "$marker"
  done

  if $ASSUME_YES; then
    printf '    %s› auto-answer: %s%s\n' "$C_YELLOW" "$def" "$C_RESET"
    printf -v "$var" '%s' "${options[$((def - 1))]}"
    return 0
  fi
  while true; do
    read -r -p "    ${C_YELLOW}›${C_RESET} Number [$def]: " reply || { echo; reply=""; }
    reply="${reply:-$def}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le "${#options[@]}" ]; then
      printf -v "$var" '%s' "${options[$((reply - 1))]}"
      return 0
    fi
    ui_warn "Type a number between 1 and ${#options[@]}."
  done
}

resolve_conflict() {
  case "$CONFLICT_POLICY" in
    backup) return 0 ;;
    skip) return 1 ;;
    *) ask_yes_no "Replace it with the dotfiles version?" y \
         "The current one is moved to ${1}.bak-${STAMP}, nothing is deleted." ;;
  esac
}

sudo_keepalive_start() {
  if ! sudo -v; then
    ui_err "sudo authentication failed."
    exit 1
  fi
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_PID=$!
  trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT
}

create_symlink() {
  local source="$1"
  local target="$2"

  if [ ! -e "$source" ]; then
    ui_err "Source does not exist: $source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$source" ]; then
      ui_ok "Already linked: $target"
      return 0
    fi
    ui_warn "Replacing existing symlink: $target"
    rm "$target"
  elif [ -e "$target" ]; then
    ui_warn "Target already exists (not a symlink): $target"
    if resolve_conflict "$target"; then
      mv "$target" "${target}.bak-${STAMP}"
      ui_ok "Backup: ${target}.bak-${STAMP}"
    else
      echo "      Skipped (real file kept)."
      return 0
    fi
  fi

  ln -s "$source" "$target"
  ui_ok "Linked: $target -> $source"
}

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
    ui_ok "Previous OozeShell moved to $BACKUP_DIR/OozeShell.bak-${STAMP}"
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
    ui_info "This OozeShell build has no native module; skipping."
    return 0
  fi
  if [ -d "$NATIVE_PREFIX/OozeShell/Native" ]; then
    ui_info "Native core already built: rebuilding it against your current Qt."
  fi

  if [ "$runner" = "nix" ]; then
    nix-shell "$shellnix" --run "bash '$script' '$NATIVE_PREFIX'" && ok=true
  else
    bash "$script" "$NATIVE_PREFIX" && ok=true
  fi

  if $ok; then
    NATIVE_OK=true
    ui_ok "Native core installed in $NATIVE_PREFIX/OozeShell/Native"
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local excl
      excl="$(git -C "$DOTFILES" rev-parse --git-path info/exclude)"
      mkdir -p "$(dirname "$excl")"
      grep -qxF ".config/quickshell/OozeShell/native/AnimationController/build/" "$excl" 2>/dev/null \
        || echo ".config/quickshell/OozeShell/native/AnimationController/build/" >> "$excl"
    fi
  else
    ui_warn "The native core did not build. OozeShell still works in pure QML."
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
  if ! $OPT_NATIVE; then return 0; fi
  if [ ! -f "$(oozeshell_tools)/build-native.sh" ]; then return 0; fi
  if command -v nix-shell >/dev/null 2>&1; then
    runner="nix"
  elif ! command -v cmake >/dev/null 2>&1; then
    ui_info "Optional native core skipped (no nix-shell and no cmake)."
    return 0
  fi
  build_native "$runner"
}

install_oozewalls() {
  local dir="$DOTFILES/OozeWalls" ok=false
  if ! $OPT_OOZEWALLS; then
    return 0
  fi
  if [ ! -f "$dir/Cargo.toml" ]; then
    ui_info "OozeWalls source not found in $dir; skipping."
    return 0
  fi
  ui_task "Building the OozeWalls engine"
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
    ui_warn "cargo not found and no nix-shell available; cannot build OozeWalls."
  fi

  if $ok; then
    OOZEWALLS_OK=true
    ui_ok "OozeWalls installed: $HOME/.local/bin/oozewalls"
  else
    ui_warn "OozeWalls did not build. Retry later with:  bash $dir/install.sh"
    FAILED+=("oozewalls (build)")
  fi
  return 0
}

# ── Arguments ──
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=true ;;
    -h|--help)
      printf 'Usage: %s [-y|--yes]\n' "$0"
      printf '  -y, --yes   accept the suggested answer to every question (unattended)\n'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

# ── Pre-checks ──
ui_banner "Oozenix / OozeShell" "Interactive installer"
echo

if [ "$(id -u)" -eq 0 ]; then
  ui_err "Do not run this installer as root (makepkg refuses, and symlinks"
  echo "    would land in /root). Run it as your normal user; sudo is used"
  echo "    only where needed."
  exit 1
fi

if [ ! -d "$DOTFILES" ]; then
  ui_err "Dotfiles directory not found: $DOTFILES"
  exit 1
fi
ui_ok "Dotfiles directory found: $DOTFILES"

if [ ! -f "$ZIP_FILE" ]; then
  ui_err "Could not find $ZIP_FILE"
  echo "    Put it there and re-run the installer."
  exit 1
fi
ui_ok "Found $(basename "$ZIP_FILE")"

if [ -L "$HOME/.config/hypr" ] && [ "$(readlink "$HOME/.config/hypr")" = "$DOTFILES/.config/hypr" ]; then
  IS_UPDATE=true
  ui_info "Existing install detected: running in update mode."
fi

# ── Questionnaire ──
ui_phase "Quick questionnaire"
ui_intro \
  "A few questions first. Nothing is changed until you confirm the summary." \
  "Press Enter to accept the suggested answer (the capital letter in [Y/n] or [y/N])."
if $ASSUME_YES; then
  ui_info "Unattended mode: every question gets its suggested answer."
fi

if [ -f /etc/arch-release ] && command -v pacman >/dev/null 2>&1; then
  ARCH_DETECTED=true
fi

if $ARCH_DETECTED; then
  ARCH_DEFAULT="y"
  ARCH_NOTE="Detected: Arch Linux."
else
  ARCH_DEFAULT="n"
  ARCH_NOTE="Detected: this does not look like Arch Linux."
fi

if ask_yes_no "Are you installing on Arch Linux?" "$ARCH_DEFAULT" \
  "$ARCH_NOTE" \
  "Yes: packages are installed for you with pacman and the AUR." \
  "No (NixOS or another distro): only the configs are linked, and the dependency" \
  "list is saved to $NIXOS_MD."; then
  IS_ARCH=true
  if ! $ARCH_DETECTED; then
    ui_warn "No /etc/arch-release or no pacman found."
    ask_yes_no "Continue with the Arch path anyway?" n \
      "It will fail at the first pacman call if this is not Arch." || exit 1
  fi
fi

if $IS_ARCH; then WIZ_TOTAL=5; else WIZ_TOTAL=4; fi

ui_wizard_section "System"
if $IS_ARCH; then
  for h in paru yay; do
    if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
  done
  if [ -n "$AUR_HELPER" ]; then
    ui_ok "AUR helper found: $AUR_HELPER"
  elif ask_yes_no "Install the AUR helper 'paru'?" y \
    "No AUR helper (paru/yay) was found." \
    "Some packages (matugen, mpvpaper, awww...) may only exist in the AUR." \
    "If you say no, those packages are skipped and listed at the end."; then
    OPT_PARU=true
  fi
  if ask_yes_no "Update the whole system first (sudo pacman -Syu)?" y \
    "Recommended: package installs do not refresh the package database, so an" \
    "old system can fail with missing files. Skip it only if you updated today."; then
    OPT_UPDATE=true
  fi
else
  if command -v unzip >/dev/null 2>&1; then
    ui_ok "unzip found: nothing to ask in this section."
  elif ! command -v nix-shell >/dev/null 2>&1; then
    ui_err "'unzip' is missing and 'nix-shell' is not available either."
    echo "    Install 'unzip' with your package manager and re-run the installer."
    exit 1
  elif ask_yes_no "Open a temporary nix-shell just to get unzip?" y \
    "'unzip' is not installed. The shell is temporary and installs nothing permanent." \
    "If you say no, the installer stops: extract OozeShell.zip by hand into $QS_DIR."; then
    ui_ok "A temporary nix-shell will be used to extract OozeShell.zip."
  else
    ui_err "Without unzip the installer cannot continue."
    exit 1
  fi
fi

ui_wizard_section "Desktop"
if $IS_ARCH; then
  ask_choice TERM_CHOICE "Which terminal should I install?" 1 \
    "The dotfiles include a config for each one; you can install more later." \
    -- foot kitty alacritty wezterm ghostty "$TERM_SKIP"
  if ask_yes_no "Enable NetworkManager, Bluetooth and power-profiles-daemon?" y \
    "OozeShell's network, Bluetooth and power panels rely on these services." \
    "Say no if you use iwd or another network stack."; then
    OPT_SERVICES=true
  fi
  if ask_yes_no "Install Waybar?" n \
    "An optional bar you can pick in OozeShell (Settings -> Bar)." \
    "Skipping it changes nothing: OozeShell's own bar keeps working."; then
    OPT_WAYBAR=true
  fi
  LEGACY_TITLE="Also install swaync, swayosd and wlogout?"
else
  LEGACY_TITLE="Also link the swaync and swayosd configs?"
fi
if ask_yes_no "$LEGACY_TITLE" n \
  "OozeShell already replaces notifications, the volume/brightness OSD and the logout screen." \
  "Only say yes if you want to use them on their own."; then
  INSTALL_LEGACY=true
fi

if $IS_ARCH; then
  ui_wizard_section "Extras and hardware"
  if ask_yes_no "Install the extras bundle?" n \
    "Dev tools (neovim, lazygit, vscodium...), gaming (lutris, wine, gamemode...)" \
    "and utilities (yazi, dolphin...). It is a large download." \
    "greetd and rtkit are installed but not configured."; then
    OPT_EXTRAS=true
  fi
  if ask_yes_no "Install the Suwayomi manga server?" n \
    "AUR package, controlled from OozeShell (Settings -> Services)." \
    "If you say no, the manual steps are saved to SuwayomiSetup.md."; then
    OPT_SUWAYOMI=true
    if ask_yes_no "Start Tachidesk right after installing it?" n \
      "It is never enabled at boot; control it from OozeShell or with 'tachidesk start'."; then
      OPT_SUWAYOMI_START=true
    fi
  fi
  if grep -qs '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null; then
    NV_DEFAULT="y"
    NV_NOTE="An Nvidia GPU was detected."
  else
    NV_DEFAULT="n"
    NV_NOTE="No Nvidia GPU was detected."
  fi
  if ask_yes_no "Enable the Nvidia variables in Hyprland's env.lua?" "$NV_DEFAULT" \
    "$NV_NOTE" \
    "On laptops with hybrid graphics, say yes only if Nvidia renders your desktop."; then
    HAS_NVIDIA=true
  fi
fi

ui_wizard_section "Optional builds"
if $IS_ARCH || command -v nix-shell >/dev/null 2>&1 || command -v cmake >/dev/null 2>&1; then
  if ask_yes_no "Build the native animation core?" n \
    "A small C++ module (about 1 minute; on Arch it also installs cmake)." \
    "OozeShell works without it in pure QML; with it the animation maths run natively."; then
    OPT_NATIVE=true
  fi
else
  ui_info "Native animation core unavailable (no nix-shell and no cmake)."
fi
if [ -f "$DOTFILES/OozeWalls/Cargo.toml" ]; then
  if ask_yes_no "Build the OozeWalls wallpaper engine?" n \
    "Written in Rust; takes a few minutes. You pick it later in Settings -> Wallpapers." \
    "On Arch cargo is installed for you; elsewhere a temporary nix-shell is used."; then
    OPT_OOZEWALLS=true
  fi
else
  ui_info "OozeWalls source not found in $DOTFILES/OozeWalls: skipping that question."
fi

ui_wizard_section "Existing files"
ask_choice CONFLICT_CHOICE "What if a config already exists in ~/.config?" 1 \
  "Applies to real files or folders, not symlinks." \
  "Backups are saved next to the original as name.bak-<date>." \
  -- "Ask me each time" "Back up and replace them all" "Keep my files and skip those links"
case "$CONFLICT_CHOICE" in
  "Back up"*) CONFLICT_POLICY="backup" ;;
  "Keep my files"*) CONFLICT_POLICY="skip" ;;
  *) CONFLICT_POLICY="ask" ;;
esac

# ── Review ──
ui_phase "Review your choices"
echo
if $IS_ARCH; then
  ui_row "System" "Arch Linux"
  if [ -z "$AUR_HELPER" ]; then ui_row "Install paru" "$(ui_yn "$OPT_PARU")"; fi
  ui_row "Full system update" "$(ui_yn "$OPT_UPDATE")"
  ui_row "Terminal" "$TERM_CHOICE"
  ui_row "Enable system services" "$(ui_yn "$OPT_SERVICES")"
  ui_row "Waybar" "$(ui_yn "$OPT_WAYBAR")"
  ui_row "swaync, swayosd, wlogout" "$(ui_yn "$INSTALL_LEGACY")"
  ui_row "Extras bundle" "$(ui_yn "$OPT_EXTRAS")"
  ui_row "Suwayomi server" "$(ui_yn "$OPT_SUWAYOMI")"
  ui_row "Nvidia variables" "$(ui_yn "$HAS_NVIDIA")"
else
  ui_row "System" "NixOS / other"
  ui_row "swaync, swayosd configs" "$(ui_yn "$INSTALL_LEGACY")"
fi
ui_row "Native animation core" "$(ui_yn "$OPT_NATIVE")"
ui_row "OozeWalls engine" "$(ui_yn "$OPT_OOZEWALLS")"
ui_row "Existing files" "$CONFLICT_CHOICE"

if ! ask_yes_no "Start the installation?" y "Nothing has been changed so far."; then
  ui_info "Cancelled. Nothing was changed."
  exit 0
fi

# ── Arch branch ──
if $IS_ARCH; then
  ui_phase "Installing on Arch Linux"
  sudo_keepalive_start

  ui_step "Preparing the system"
  if [ -z "$AUR_HELPER" ] && $OPT_PARU; then
    sudo pacman -S --needed --noconfirm base-devel git
    PARU_TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru-bin.git "$PARU_TMP/paru-bin"
    (cd "$PARU_TMP/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$PARU_TMP"
    AUR_HELPER="paru"
  fi
  if [ -z "$AUR_HELPER" ]; then
    ui_warn "No AUR helper: AUR-only packages will be reported at the end."
  fi
  ui_ok "AUR helper: ${AUR_HELPER:-none}"

  if $OPT_UPDATE; then
    ui_task "Updating the system"
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
        ui_warn "Batch failed; retrying one by one..."
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
          ui_warn "Batch failed; retrying one by one..."
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
      ui_warn "hyprland $ver is older than 0.55: the Lua config (hyprland.lua) needs 0.55 or newer."
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
    ui_ok "Steps saved to: $SUWAYOMI_MD"
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
      ui_ok "Control command: $TACHIDESK_CTL_SYS  (tachidesk start|stop|restart|status|enable|disable)"
      if [ -f "$TACHIDESK_CTL_USER" ] && [ ! -L "$TACHIDESK_CTL_USER" ]; then
        mv -f "$TACHIDESK_CTL_USER" "${TACHIDESK_CTL_USER}.bak-${STAMP}"
        ui_info "Old copy moved to ${TACHIDESK_CTL_USER}.bak-${STAMP}"
      fi
    else
      ui_warn "Could not write to $TACHIDESK_CTL_SYS (sudo failed); using ~/.local/bin instead."
      mkdir -p "$(dirname "$TACHIDESK_CTL_USER")"
      if [ -e "$TACHIDESK_CTL_USER" ]; then cp -f "$TACHIDESK_CTL_USER" "${TACHIDESK_CTL_USER}.bak-${STAMP}"; fi
      install -m755 "$tmp" "$TACHIDESK_CTL_USER"
      ui_ok "Control command: $TACHIDESK_CTL_USER"
      ui_warn "OozeShell only finds it if ~/.local/bin is in the PATH of your Hyprland session."
      echo "      Otherwise the Services page will not be able to control the server."
    fi
    rm -f "$tmp"
  }

  setup_suwayomi() {
    local bin

    if ! bin="$(find_suwayomi_bin)"; then
      ui_warn "Could not find the Suwayomi executable; skipping the service setup."
      write_suwayomi_md
      return 0
    fi
    ui_ok "Suwayomi executable: $bin"

    mkdir -p "$HOME/.local/share/Tachidesk/extensions" "$HOME/.local/share/Tachidesk/backups" \
             "$HOME/Manga/Downloads" "$HOME/.config/systemd/user"

    if [ -e "$TACHIDESK_UNIT" ]; then cp -f "$TACHIDESK_UNIT" "${TACHIDESK_UNIT}.bak-${STAMP}"; fi
    tachidesk_unit_body "$bin" > "$TACHIDESK_UNIT"
    ui_ok "User service: $TACHIDESK_UNIT"

    install_tachidesk_ctl

    if systemctl --user daemon-reload 2>/dev/null; then
      if systemctl --user cat tachidesk.service >/dev/null 2>&1; then
        ui_ok "systemd sees tachidesk.service"
        SUWAYOMI_OK=true
      else
        ui_warn "systemd did not load tachidesk.service; check: systemctl --user cat tachidesk.service"
      fi
    else
      ui_warn "Could not reload the user systemd session; run 'systemctl --user daemon-reload' after logging in."
      SUWAYOMI_OK=true
    fi

    if ! systemctl --user is-active --quiet tachidesk.service 2>/dev/null \
       && pgrep -f -i 'java.*(suwayomi|tachidesk)' >/dev/null 2>&1; then
      ui_warn "A Suwayomi process is already running (started by hand?)."
      echo "      Stop it before using the service, or the port will be busy:"
      echo "        pkill -TERM -f -i suwayomi"
    fi

    ui_info "Not started or enabled on boot (same as NixOS)."
    echo "      Control it from OozeShell (Settings -> Services) or with: tachidesk start"
    if $OPT_SUWAYOMI_START; then
      tachidesk start || ui_warn "'tachidesk start' failed; see: tachidesk status"
      sleep 2
      tachidesk status 2>&1 | sed -n '1,6p' || true
    fi
  }

  # ── Base packages ──
  ui_step "Installing base packages"
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
    mpv mpvpaper ffmpeg socat xdg-utils xdg-user-dirs libpulse
    libnotify imagemagick wtype wev grim slurp wf-recorder cava pavucontrol fastfetch
    qpwgraph rofi tmux
    matugen
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono noto-fonts-emoji
    ttf-silkscreen ttf-dotgothic16 ttf-vt323
  )

  ui_task "Installing base dependencies"
  install_pkgs "${BASE[@]}"
  if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update >/dev/null 2>&1 || true
  fi
  fc-cache -f >/dev/null 2>&1 || true
  ui_task "Installing quickshell and awww (release or -git, whichever is available)"
  install_first quickshell quickshell-git
  install_first awww awww-git
  check_hyprland
  echo

  # ── Clipboard tools ──
  ui_task "Installing clipboard tools (wl-clipboard + cliphist)"
  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    ui_ok "wl-copy / wl-paste already available"
  else
    install_first wl-clipboard wl-clipboard-rs
  fi
  if command -v cliphist >/dev/null 2>&1; then
    ui_ok "cliphist already available"
  else
    install_first cliphist cliphist-git
  fi
  for c in wl-copy wl-paste cliphist; do
    if ! command -v "$c" >/dev/null 2>&1; then
      ui_warn "'$c' is still missing: the clipboard history panel will show its 'missing dependencies' notice."
      FAILED+=("clipboard: $c")
    fi
  done
  echo

  # ── Terminal ──
  ui_step "Terminal and system services"
  if [ "$TERM_CHOICE" != "$TERM_SKIP" ]; then
    install_pkgs "$TERM_CHOICE"
  fi
  echo

  # ── Services ──
  if $OPT_SERVICES; then
    for svc in NetworkManager bluetooth power-profiles-daemon; do
      sudo systemctl enable --now "$svc" || FAILED+=("service:$svc")
    done
  fi
  echo

  ui_info "Package search (SUPER+U): OozeShell detects Arch on its own and searches with"
  echo "    paru/yay/pacman + AUR (no Nix needed). The keybind stays on 'nixsearch' (IPC name)."
  echo

  # ── Optional packages ──
  ui_step "Optional packages"
  if $OPT_WAYBAR; then
    install_pkgs waybar
  fi
  if $INSTALL_LEGACY; then
    install_pkgs swaync swayosd wlogout
  fi
  echo

  # ── Extras ──
  if $OPT_EXTRAS; then
    EXTRAS=(
      greetd greetd-tuigreet udisks2 rtkit flatpak yazi neovim starship
      fd ripgrep dolphin nomacs gamemode lutris mangohud wine
      github-cli jdk21-openjdk lazygit python-pip tree
      qt6-quick3d wget vim uv ruff
      bibata-cursor-theme prismlauncher protonplus protontricks
      goverlay vscodium-bin nixd nixfmt pw-viz
    )
    install_pkgs "${EXTRAS[@]}"
    ui_info "greetd and rtkit were installed but NOT configured/enabled; set them up by hand if you want them."
  fi

  echo
  # ── Suwayomi ──
  if $OPT_SUWAYOMI; then
    install_first jre21-openjdk jdk21-openjdk jdk-openjdk jre-openjdk
    install_pkgs suwayomi-server-bin
    setup_suwayomi
  else
    ui_info "Skipping Suwayomi. Writing the manual steps for later..."
    write_suwayomi_md
  fi

  echo
  # ── Unpacking ──
  ui_step "Unpacking OozeShell"
  ui_ok "Unzipping OozeShell.zip..."
  extract_oozeshell "$ZIP_FILE"

  # ── Fonts ──
  FC_SRC="$(oozeshell_tools)/fonts/99-oozeshell-pixel.conf"
  if [ -f "$FC_SRC" ]; then
    mkdir -p "$HOME/.config/fontconfig/conf.d"
    cp -f "$FC_SRC" "$HOME/.config/fontconfig/conf.d/"
    fc-cache -f >/dev/null 2>&1 || true
    ui_ok "fontconfig installed (icon fallback)"
  fi

  # ── Native core ──
  if [ -f "$(oozeshell_tools)/build-native.sh" ]; then
    echo
    if $OPT_NATIVE; then
      install_pkgs cmake
      if command -v cmake >/dev/null 2>&1; then
        build_native
      else
        ui_warn "cmake is missing; skipping the native core."
      fi
    fi
  fi

# ── Non-Arch branch ──
else
  ui_phase "Installing on NixOS / other distro"
  ui_info "Only NixOS and Arch are fully supported. On another distro, adapt the list in $NIXOS_MD."

  ui_step "Unpacking OozeShell"
  ui_ok "Unzipping OozeShell.zip..."
  if command -v unzip >/dev/null 2>&1; then
    extract_oozeshell "$ZIP_FILE"
  else
    extract_oozeshell "$ZIP_FILE" nix
  fi

  maybe_build_native_other

  ui_step "Writing the dependency list"
  ui_info "Writing $NIXOS_MD with the dependency list..."
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
- zsh (the dotfiles link a `.zshrc`)
- rofi (alternative Launcher / PowerMenu backend)
- Qt6: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Shapes,
  QtQuick.Effects, QtQml, qt6ct
- Nerd Fonts: "JetBrainsMono Nerd Font" and "Symbols Nerd Font Mono"
- wpctl, pw-dump, pw-link, pw-cli, pw-loopback (pipewire + wireplumber)
- pactl (libpulse; used by screen recording to pick the audio device)
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
- xdg-user-dirs (xdg-user-dir; finds your Pictures and Videos folders)
- jq
- curl (online wallpapers and downloads)
- python3 >= 3.11 (palette-apply.py: applies the fixed Palettes to the matugen
  templates, i.e. terminals, Hyprland, Qt/KDE, etc.)
- fastfetch
- pgrep
- A terminal: foot, kitty, alacritty, wezterm, or ghostty
- libnotify (notify-send)
- imagemagick
- wtype
- wev
- grim
- slurp
- wf-recorder (screen recording)
- cava
- pavucontrol
- qpwgraph (audio routing graph)
- A color emoji font (Noto Color Emoji)
- awww (current successor to swww)
- Optional, GPU stats: nvidia-smi (NVIDIA) or the amdgpu sysfs counters
- Optional, to-do alarm sound: pw-play or paplay (pipewire / libpulse)
- Optional, faster online wallpaper downloads: aria2 (falls back to curl)
- Optional, safer storage of AI agent API keys: libsecret (secret-tool) and a
  keyring such as gnome-keyring (falls back to an encrypted file using openssl)

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
  ui_ok "Done: $NIXOS_MD"
fi

# ── Symlinks and permissions ──
ui_step "Linking configuration"

mkdir -p "$HOME/.config" "$HOME/.local/bin"

ui_task "Creating .config symlinks"

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
ui_task "Creating home & binary symlinks"

create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES/random-fastfetch" "$HOME/.local/bin/random-fastfetch"
if ! $IS_ARCH; then
  create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"
fi

echo
ui_task "Granting execution permissions"

scripts=(
  "$(oozeshell_services)/OozeAudio/backend/audio.sh"
  "$(oozeshell_services)/PackageSearch/installed.sh"
  "$(oozeshell_tools)/build-native.sh"
  "$(oozeshell_tools)/live-optimize.sh"
  "$(oozeshell_tools)/online-wallpapers.sh"
  "$(oozeshell_tools)/ooze-launch.sh"
  "$(oozeshell_tools)/ooze-run.sh"
  "$(oozeshell_tools)/check.sh"
  "$(oozeshell_tools)/palette-apply.py"
  "$(oozeshell_tools)/oozeshell"
  "$QS_DIR/OozeShell/Modules/Keybinds/keybinds_tool.py"
  "$QS_DIR/OozeShell/Backends/python/ooze-daemon.py"
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
    ui_ok "Executable: $script"
  else
    ui_err "Script file not found: $script"
  fi
done

if [ -d "$QS_DIR/OozeShell" ]; then
  find "$QS_DIR/OozeShell" -type f \( -name '*.sh' -o -name '*.py' \) \
    -not -path '*/native/*/build/*' ! -perm -u+x -exec chmod +x {} + 2>/dev/null || true
  ui_ok "Swept remaining *.sh / *.py inside OozeShell"
fi

# ── Keybinds: migrate legacy IPC calls ──
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
      ui_ok "IPC calls updated in $f (backup: ${f}.bak-${STAMP})"
    fi
  done
}
ui_step "Finishing up"
migrate_ipc_binds
echo

# ── oozeshell: short launcher for the IPC (oozeshell apps open browser) ──
OOZESHELL_TOOL="$(oozeshell_tools)/oozeshell"
if [ -f "$OOZESHELL_TOOL" ]; then
  chmod +x "$OOZESHELL_TOOL"
  create_symlink "$OOZESHELL_TOOL" "$HOME/.local/bin/oozeshell"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) ui_warn "~/.local/bin is not in PATH; add it to use 'oozeshell' from a terminal." ;;
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
    ui_ok "env.lua: ELECTRON_OZONE_PLATFORM_HINT enabled"
    if $HAS_NVIDIA; then
      sed -i -E 's/^--[[:space:]]*(hl\.env\("LIBVA_DRIVER_NAME", "nvidia"\).*)$/\1/' "$ENVLUA"
      sed -i -E 's/^--[[:space:]]*(hl\.env\("__GLX_VENDOR_LIBRARY_NAME", "nvidia"\).*)$/\1/' "$ENVLUA"
      ui_ok "env.lua: Nvidia variables enabled (LIBVA_DRIVER_NAME, __GLX_VENDOR_LIBRARY_NAME)"
    fi
    echo "      Backup: ${ENVLUA}.bak-${STAMP}"
  else
    ui_err "env.lua not found: $ENVLUA"
  fi
  echo
fi

# ── Native core: QML_IMPORT_PATH ──
if $NATIVE_OK; then
  ENVLUA="$HOME/.config/hypr/modules/system/env.lua"
  QML_LINE='hl.env("QML_IMPORT_PATH", os.getenv("HOME") .. "/.local/share/oozeshell/qml")'
  if [ -f "$ENVLUA" ]; then
    if grep -q 'QML_IMPORT_PATH' "$ENVLUA"; then
      ui_ok "env.lua already sets QML_IMPORT_PATH"
    else
      [ -f "${ENVLUA}.bak-${STAMP}" ] || cp -f "$ENVLUA" "${ENVLUA}.bak-${STAMP}"
      printf '\n-- OozeShell native core (added by install-oozenix.sh)\n%s\n' "$QML_LINE" >> "$ENVLUA"
      ui_ok "env.lua: QML_IMPORT_PATH added (log out and back in to apply)"
    fi
  else
    ui_warn "env.lua not found: $ENVLUA"
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
    ui_ok "Git now ignores local changes in $AUTOGEN_REL (generated by OozeShell)"
    echo "      Undo: git -C ~/dotfiles ls-files -z $AUTOGEN_REL | xargs -0 git -C ~/dotfiles update-index --no-skip-worktree"
    echo
  fi
fi

# ── Summary ──
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  ui_warn "These packages/services were NOT installed:"
  for f in "${FAILED[@]}"; do echo "      - $f"; done
  echo "      Check the names with: pacman -Ss <name>  /  ${AUR_HELPER:-paru} -Ss <name>"
fi

ui_banner "Oozenix installation complete"
echo
echo "Restart:        log out and back in (or reboot) to start OozeShell safely, so the"
echo "                session environment and autostart apply cleanly."
echo "Manual start:   bash $(oozeshell_tools)/ooze-launch.sh   (restarts it cleanly, with the memory tuning)"
echo "IPC:            oozeshell list   (targets/functions)  ·  oozeshell apps open browser"
if ! command -v waybar >/dev/null 2>&1; then
  echo "Waybar:         not installed; the Waybar option in Settings -> Bar stays disabled until you install it"
fi
if $NATIVE_OK; then
  echo "Native core:    after restarting, the log should say '[theme] núcleo nativo: activo'"
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