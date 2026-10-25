#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$HOME/dotfiles"
INSTALLER="$DOTFILES/install-oozenix.sh"
NIXOS_MD="$DOTFILES/NixOSInstallation.md"
QS_DIR="$DOTFILES/.config/quickshell"
ZIP_FILE="$DOTFILES/OozeShell.zip"
STAMP="$(date +%Y%m%d-%H%M%S)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell"
BACKUP_DIR="$DATA_DIR/backups"
STATE_FILE="$DATA_DIR/update-state"
NATIVE_PREFIX="$HOME/.local/share/oozeshell/qml"
ENVLUA="$HOME/.config/hypr/modules/system/env.lua"
AUTOGEN_REL=".config/hypr/modules/appearance/autogen"
TACHIDESK_CTL_SYS="/usr/local/bin/tachidesk"

YES=false
CHECK=false
FORCE=false
SYSTEM=false
IS_ARCH=false
INSTALL_LEGACY=false
HAS_NVIDIA=false
STASHED=false
STASH_KEPT=false
PULL_FAILED=false
SHELL_CHANGED=false
RESTART_NEEDED=false
ENV_CHANGED=false
EXTRACT_FAILED=false
SUDO_READY=false
SUDO_PID=""
CONFLICT_POLICY="ask"
AUR_HELPER=""
UPSTREAM=""
AHEAD=0
BEHIND=0
OLD_HEAD=""
NEW_HEAD=""
CHANGED_FILES=""
AUTOGEN_BAK=""
CUR_ZIP=""
INSTALLED_ZIP=""
QT_RECORDED=""
QT_NOW=""
FAILED=()
FOREIGN_LINKS=()
BASE=()

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

ui_step() {
  UI_STEP=$((UI_STEP + 1))
  printf '\n%s%s▶ Step %s · %s%s\n' "$C_BOLD" "$C_CYAN" "$UI_STEP" "$1" "$C_RESET"
}

ui_task() { printf '  %s•%s %s\n' "$C_BLUE" "$C_RESET" "$1"; }
ui_ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
ui_warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
ui_err() { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; }
ui_info() { printf '  %si%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; }
ui_more() { printf '      %s\n' "$1"; }

# ── Helpers ──
usage() {
  cat << 'EOF'
Usage: update-oozenix.sh [options]

  --check     Only report whether an update is available
  --system    Also run a full system update (Arch)
  --force     Redo extraction, native build and link checks even without changes
  --replace   Back up and replace real files that block a link (no questions)
  --keep      Keep real files that block a link (no questions)
  -y, --yes   Never ask; use the safe default for every question
  -h, --help  Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) CHECK=true ;;
      --system) SYSTEM=true ;;
      --force) FORCE=true ;;
      --replace) CONFLICT_POLICY="backup" ;;
      --keep) CONFLICT_POLICY="skip" ;;
      -y|--yes) YES=true ;;
      -h|--help) usage; exit 0 ;;
      *) ui_err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

ask_yes_no() {
  local title="$1" def="$2" hint reply line
  shift 2
  printf '\n  %s?%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  for line in "$@"; do
    printf '    %s%s%s\n' "$C_DIM" "$line" "$C_RESET"
  done
  if [ "$def" = "y" ]; then hint="Y/n"; else hint="y/N"; fi
  if $YES; then
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

resolve_conflict() {
  case "$CONFLICT_POLICY" in
    backup) return 0 ;;
    skip) return 1 ;;
    *) ask_yes_no "Replace it with the dotfiles version?" n \
         "The current one is moved to ${1}.bak-${STAMP}, nothing is deleted." ;;
  esac
}

sudo_keepalive_start() {
  if $SUDO_READY; then return 0; fi
  if ! sudo -v; then
    ui_err "sudo authentication failed."
    exit 1
  fi
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_PID=$!
  SUDO_READY=true
}

on_exit() {
  local rc=$?
  if [ -n "$SUDO_PID" ]; then kill "$SUDO_PID" 2>/dev/null || true; fi
  if [ "$rc" -ne 0 ]; then
    if $STASHED; then
      ui_warn "Stopped early. Your local changes are in the stash: git -C ~/dotfiles stash pop"
    fi
    if [ -n "$AUTOGEN_BAK" ] && [ -d "$AUTOGEN_BAK" ]; then
      ui_warn "Stopped early. Your generated appearance files are saved in: $AUTOGEN_BAK"
    fi
  fi
}
trap on_exit EXIT

state_get() {
  if [ ! -f "$STATE_FILE" ]; then return 0; fi
  sed -n "s/^$1=//p" "$STATE_FILE" | head -n1
}

state_set() {
  local tmp="$STATE_FILE.tmp"
  mkdir -p "$(dirname "$STATE_FILE")"
  if [ -f "$STATE_FILE" ]; then
    grep -v "^$1=" "$STATE_FILE" > "$tmp" || true
  else
    : > "$tmp"
  fi
  echo "$1=$2" >> "$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

file_hash() {
  sha256sum "$1" | cut -d' ' -f1
}

oozeshell_tools() {
  if [ -d "$QS_DIR/OozeShell/Tools" ]; then
    printf '%s\n' "$QS_DIR/OozeShell/Tools"
  else
    printf '%s\n' "$QS_DIR/OozeShell/tools"
  fi
}

changed_in() {
  printf '%s\n' "$CHANGED_FILES" | awk -v p="$1" 'index($0, p) == 1 { found = 1 } END { exit !found }'
}

git_exclude() {
  local excl
  excl="$(git -C "$DOTFILES" rev-parse --absolute-git-dir)/info/exclude"
  mkdir -p "$(dirname "$excl")"
  grep -qxF "$1" "$excl" 2>/dev/null || echo "$1" >> "$excl"
}

qt_version() {
  if $IS_ARCH; then
    pacman -Q qt6-base 2>/dev/null | awk '{print $2}' || true
  fi
}

qt_changed() {
  if [ -z "$QT_RECORDED" ] || [ -z "$QT_NOW" ]; then return 1; fi
  [ "$QT_RECORDED" != "$QT_NOW" ]
}

zip_changed() {
  [ -n "$CUR_ZIP" ] && [ "$CUR_ZIP" != "$INSTALLED_ZIP" ]
}

# ── Pre-checks ──
pre_checks() {
  local gitdir

  if [ "$(id -u)" -eq 0 ]; then
    ui_err "Do not run this updater as root. Run it as your normal user."
    exit 1
  fi
  if [ ! -d "$DOTFILES" ]; then
    ui_err "Dotfiles directory not found: $DOTFILES"
    exit 1
  fi
  if ! git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ui_err "$DOTFILES is not a git repository."
    exit 1
  fi
  if [ ! -L "$HOME/.config/hypr" ] || [ "$(readlink "$HOME/.config/hypr")" != "$DOTFILES/.config/hypr" ]; then
    ui_err "No existing install detected (~/.config/hypr is not linked to the dotfiles)."
    ui_more "Run install-oozenix.sh first."
    exit 1
  fi
  if [ ! -f "$INSTALLER" ]; then
    ui_err "Could not find $INSTALLER"
    exit 1
  fi

  gitdir="$(git -C "$DOTFILES" rev-parse --absolute-git-dir)"
  if [ -e "$gitdir/MERGE_HEAD" ] || [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ]; then
    ui_err "A merge or rebase is in progress in $DOTFILES. Finish or abort it first."
    exit 1
  fi
  if ! UPSTREAM="$(git -C "$DOTFILES" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
    ui_err "The current branch has no upstream."
    ui_more "Fix it with: git -C ~/dotfiles branch --set-upstream-to=origin/main"
    exit 1
  fi
  ui_ok "Existing install found: $DOTFILES (tracking $UPSTREAM)"
}

detect_distro() {
  local h
  if [ -f /etc/arch-release ] && command -v pacman >/dev/null 2>&1; then
    IS_ARCH=true
    for h in paru yay; do
      if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
    done
    ui_ok "Arch Linux detected (AUR helper: ${AUR_HELPER:-none})"
  else
    ui_ok "Non-Arch system: packages are managed outside this updater"
  fi
}

snapshot_state() {
  local d
  for d in swaync swayosd; do
    if [ -L "$HOME/.config/$d" ] && [ "$(readlink "$HOME/.config/$d")" = "$DOTFILES/.config/$d" ]; then
      INSTALL_LEGACY=true
    fi
  done
  if grep -qE '^hl\.env\("(LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME)", "nvidia"\)' "$ENVLUA" 2>/dev/null; then
    HAS_NVIDIA=true
  fi
  if [ -f "$ZIP_FILE" ]; then CUR_ZIP="$(file_hash "$ZIP_FILE")"; fi
  INSTALLED_ZIP="$(state_get zip)"
  if [ -z "$INSTALLED_ZIP" ] && git -C "$DOTFILES" cat-file -e "HEAD:OozeShell.zip" 2>/dev/null; then
    INSTALLED_ZIP="$(git -C "$DOTFILES" show "HEAD:OozeShell.zip" | sha256sum | cut -d' ' -f1)"
  fi
  QT_RECORDED="$(state_get qt)"
  QT_NOW="$(qt_version)"
}

# ── Repository ──
fetch_remote() {
  ui_task "Checking $UPSTREAM"
  if ! git -C "$DOTFILES" fetch --quiet; then
    ui_err "Could not reach the remote. Check your connection."
    exit 1
  fi
  read -r AHEAD BEHIND < <(git -C "$DOTFILES" rev-list --left-right --count "HEAD...@{u}")
  if [ "$BEHIND" -gt 0 ]; then
    ui_info "$BEHIND new commit(s) available:"
    git -C "$DOTFILES" log --oneline --no-decorate -n 10 "HEAD..@{u}" | sed 's/^/      /'
    if [ "$BEHIND" -gt 10 ]; then ui_more "... and $((BEHIND - 10)) more"; fi
  else
    ui_ok "No new commits on $UPSTREAM"
  fi
  if [ "$AHEAD" -gt 0 ]; then
    ui_info "You have $AHEAD local commit(s) not pushed."
  fi
}

nothing_to_do() {
  if [ "$BEHIND" -gt 0 ] || $FORCE || $SYSTEM; then return 1; fi
  if [ ! -d "$QS_DIR/OozeShell" ]; then return 1; fi
  if zip_changed; then return 1; fi
  if qt_changed; then return 1; fi
  return 0
}

save_autogen() {
  local f
  AUTOGEN_BAK="$(mktemp -d)"
  while IFS= read -r -d '' f; do
    if [ -f "$DOTFILES/$f" ]; then
      mkdir -p "$AUTOGEN_BAK/$(dirname "$f")"
      cp -f "$DOTFILES/$f" "$AUTOGEN_BAK/$f"
    fi
  done < <(git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL")
  git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL" | xargs -0 -r git -C "$DOTFILES" update-index --no-skip-worktree
  git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL" | xargs -0 -r git -C "$DOTFILES" checkout --quiet --
}

restore_autogen() {
  local f
  while IFS= read -r -d '' f; do
    if [ -f "$AUTOGEN_BAK/$f" ]; then cp -f "$AUTOGEN_BAK/$f" "$DOTFILES/$f"; fi
  done < <(git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL")
  rm -rf "$AUTOGEN_BAK"
  AUTOGEN_BAK=""
  if [ -n "$(git -C "$DOTFILES" ls-files "$AUTOGEN_REL")" ]; then
    git -C "$DOTFILES" ls-files -z "$AUTOGEN_REL" | xargs -0 git -C "$DOTFILES" update-index --skip-worktree
    git_exclude "$AUTOGEN_REL/"
  fi
}

stash_local() {
  if [ -n "$(git -C "$DOTFILES" status --porcelain --untracked-files=no)" ]; then
    git -C "$DOTFILES" stash push --quiet -m "oozenix-update-${STAMP}"
    STASHED=true
    ui_ok "Local changes set aside (stash)"
  fi
}

unstash_local() {
  if ! $STASHED; then return 0; fi
  if git -C "$DOTFILES" stash pop --quiet; then
    ui_ok "Local changes re-applied"
  else
    git -C "$DOTFILES" reset --hard --quiet HEAD
    STASH_KEPT=true
    ui_warn "Your local changes conflict with the update."
    ui_more "The repository is clean on the new version; nothing was lost, your changes"
    ui_more "are kept in the stash. Review and re-apply them by hand:"
    ui_more "  git -C ~/dotfiles stash show -p"
    ui_more "  git -C ~/dotfiles stash pop"
  fi
  STASHED=false
}

pull_upstream() {
  if [ "$BEHIND" -eq 0 ]; then return 0; fi
  if [ "$AHEAD" -eq 0 ]; then
    if git -C "$DOTFILES" merge --ff-only --quiet '@{u}'; then
      ui_ok "Fast-forwarded to $UPSTREAM"
      return 0
    fi
    ui_err "Fast-forward failed."
    return 1
  fi
  ui_warn "Your branch diverged from $UPSTREAM ($AHEAD local, $BEHIND remote)."
  if ask_yes_no "Rebase your local commits on top of the remote ones?" n \
    "If the rebase has conflicts it is aborted and nothing changes."; then
    if git -C "$DOTFILES" rebase --quiet '@{u}'; then
      ui_ok "Rebased onto $UPSTREAM"
      return 0
    fi
    git -C "$DOTFILES" rebase --abort || true
    ui_err "The rebase had conflicts and was aborted. Nothing was changed."
    return 1
  fi
  ui_more "Skipped. Resolve it by hand: git -C ~/dotfiles pull --rebase"
  return 1
}

sync_repo() {
  OLD_HEAD="$(git -C "$DOTFILES" rev-parse HEAD)"
  save_autogen
  stash_local
  if ! pull_upstream; then PULL_FAILED=true; fi
  unstash_local
  restore_autogen
  NEW_HEAD="$(git -C "$DOTFILES" rev-parse HEAD)"
  if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
    CHANGED_FILES="$(git -C "$DOTFILES" diff --name-only "$OLD_HEAD" "$NEW_HEAD")"
    RESTART_NEEDED=true
  fi
}

# ── Arch ──
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
    sudo_keepalive_start
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
    elif $YES; then
      for p in "${aur[@]}"; do FAILED+=("$p (AUR, not built with --yes)"); done
    elif ! "$AUR_HELPER" -S --needed "${aur[@]}"; then
      ui_warn "Batch failed; retrying one by one..."
      for p in "${aur[@]}"; do
        "$AUR_HELPER" -S --needed "$p" || FAILED+=("$p")
      done
    fi
  fi
}

install_first() {
  local p
  for p in "$@"; do
    if pkg_installed "$p"; then return 0; fi
  done
  if $YES && [ -z "$AUR_HELPER" ]; then
    FAILED+=("$* (no variant could be installed)")
    return 0
  fi
  sudo_keepalive_start
  for p in "$@"; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      if sudo pacman -S --needed --noconfirm "$p"; then return 0; fi
    elif [ -n "$AUR_HELPER" ] && ! $YES && "$AUR_HELPER" -Si "$p" >/dev/null 2>&1; then
      if "$AUR_HELPER" -S --needed "$p"; then return 0; fi
    fi
  done
  FAILED+=("$* (no variant could be installed)")
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

system_update() {
  if ! $IS_ARCH; then return 0; fi
  if ! $SYSTEM; then
    if ! ask_yes_no "Run a full system update (sudo pacman -Syu)?" n \
      "Arch does not support partial updates: update everything or nothing." \
      "Recommended when the Qt or Hyprland versions are behind."; then
      return 0
    fi
  fi
  sudo_keepalive_start
  ui_task "Updating the system"
  if ! sudo pacman -Syu --noconfirm; then
    FAILED+=("system update (pacman -Syu)")
    return 0
  fi
  QT_NOW="$(qt_version)"
  if [ -z "$AUR_HELPER" ]; then return 0; fi
  if $YES; then
    ui_info "AUR packages were not updated (--yes). Run: $AUR_HELPER -Sua --devel"
  elif ! "$AUR_HELPER" -Sua --devel; then
    FAILED+=("AUR update ($AUR_HELPER -Sua)")
  fi
}

check_variants() {
  local group p found
  local missing=()
  for group in "quickshell quickshell-git" "awww awww-git" "wl-clipboard wl-clipboard-rs" "cliphist cliphist-git"; do
    found=false
    for p in $group; do
      if pkg_installed "$p"; then found=true; fi
    done
    if ! $found; then missing+=("$group"); fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then return 0; fi
  ui_info "Missing (any variant works): ${missing[*]}"
  if ask_yes_no "Install them?" y \
    "Release or -git, whichever is available, same as the installer."; then
    for group in "${missing[@]}"; do
      # shellcheck disable=SC2086
      install_first $group
    done
  fi
}

update_packages() {
  local missing=() p
  if ! $IS_ARCH; then return 0; fi

  mapfile -t BASE < <(sed -n '/^  BASE=(/,/^  )/p' "$INSTALLER" | sed '1d;$d' | tr -s ' \t' '\n\n' | grep -v '^$')
  if [ "${#BASE[@]}" -eq 0 ]; then
    ui_warn "Could not read the BASE list from install-oozenix.sh; package check skipped."
    return 0
  fi
  for p in "${BASE[@]}"; do
    if ! pkg_installed "$p"; then missing+=("$p"); fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    ui_ok "All base packages are installed"
  else
    ui_info "Missing base packages: ${missing[*]}"
    if ask_yes_no "Install them?" y "Packages added to the installer since your last run."; then
      install_pkgs "${missing[@]}"
    fi
  fi
  check_variants
  check_hyprland
}

update_tachidesk_ctl() {
  local tmp
  if ! $IS_ARCH || [ ! -e "$TACHIDESK_CTL_SYS" ]; then return 0; fi
  tmp="$(mktemp)"
  cat > "$tmp" << 'EOF'
#!/usr/bin/env bash
case "$1" in
  start|stop|restart|enable|disable) systemctl --user "$1" tachidesk.service ;;
  status) systemctl --user status tachidesk.service --no-pager ;;
  *) echo "Usage: tachidesk {start|stop|restart|status|enable|disable}"; exit 1 ;;
esac
EOF
  chmod +x "$tmp"
  if cmp -s "$tmp" "$TACHIDESK_CTL_SYS"; then
    rm -f "$tmp"
    return 0
  fi
  if ask_yes_no "Refresh the 'tachidesk' control command?" y \
    "The installed copy differs from the one the installer writes." \
    "The old one is saved as ${TACHIDESK_CTL_SYS}.bak-${STAMP}."; then
    sudo_keepalive_start
    sudo cp -f "$TACHIDESK_CTL_SYS" "${TACHIDESK_CTL_SYS}.bak-${STAMP}" || true
    if sudo install -Dm755 "$tmp" "$TACHIDESK_CTL_SYS"; then
      ui_ok "Updated: $TACHIDESK_CTL_SYS"
    else
      FAILED+=("tachidesk control command")
    fi
  fi
  rm -f "$tmp"
}

# ── OozeShell ──
extract_oozeshell() {
  local zip="$1" backup="" ok=false

  if ! command -v unzip >/dev/null 2>&1 && ! command -v nix-shell >/dev/null 2>&1; then
    ui_err "'unzip' is missing and there is no nix-shell to borrow it. Install unzip and run again."
    return 1
  fi
  mkdir -p "$QS_DIR"
  if [ -d "$QS_DIR/OozeShell" ]; then
    mkdir -p "$BACKUP_DIR"
    backup="$BACKUP_DIR/OozeShell.bak-${STAMP}"
    mv "$QS_DIR/OozeShell" "$backup"
  fi

  if command -v unzip >/dev/null 2>&1; then
    unzip -qo "$zip" -d "$QS_DIR" && ok=true
  else
    nix-shell -p unzip --run "unzip -qo '$zip' -d '$QS_DIR'" && ok=true
  fi

  if ! $ok; then
    rm -rf "$QS_DIR/OozeShell"
    if [ -n "$backup" ]; then mv "$backup" "$QS_DIR/OozeShell"; fi
    ui_err "Extraction failed; your previous OozeShell was put back."
    return 1
  fi
  rm -rf "$QS_DIR/OozeShell/native/AnimationController/build"
  if [ -n "$backup" ]; then
    ui_ok "Previous OozeShell moved to $backup"
  fi
  ui_ok "OozeShell extracted from $(basename "$zip")"
}

update_oozeshell() {
  if [ ! -f "$ZIP_FILE" ]; then
    ui_err "Could not find $ZIP_FILE"
    FAILED+=("OozeShell.zip (not found)")
    EXTRACT_FAILED=true
    return 0
  fi
  CUR_ZIP="$(file_hash "$ZIP_FILE")"

  if [ -n "$(git -C "$DOTFILES" ls-files ".config/quickshell/OozeShell" | head -n1)" ] && ! $FORCE; then
    ui_info "OozeShell is tracked by git here: the pull already updated it, the zip is not extracted."
    ui_more "Use --force to extract the zip over it."
    if changed_in ".config/quickshell/OozeShell/"; then SHELL_CHANGED=true; fi
    return 0
  fi

  if ! $FORCE && [ -d "$QS_DIR/OozeShell" ] && [ "$CUR_ZIP" = "$INSTALLED_ZIP" ]; then
    ui_ok "OozeShell is already up to date"
    return 0
  fi

  ui_task "Extracting the new OozeShell"
  if extract_oozeshell "$ZIP_FILE"; then
    SHELL_CHANGED=true
    RESTART_NEEDED=true
  else
    EXTRACT_FAILED=true
    FAILED+=("OozeShell (extraction)")
  fi
}

update_native() {
  local script shellnix ok=false
  script="$(oozeshell_tools)/build-native.sh"
  shellnix="$QS_DIR/OozeShell/native/shell.nix"

  if [ ! -d "$NATIVE_PREFIX/OozeShell/Native" ]; then return 0; fi
  if ! $FORCE && ! $SHELL_CHANGED && ! qt_changed; then
    ui_ok "Native core is current"
    return 0
  fi
  if [ ! -f "$script" ]; then
    ui_info "This OozeShell build has no native module; skipping."
    return 0
  fi

  ui_task "Rebuilding the native core against your current Qt"
  rm -rf "$QS_DIR/OozeShell/native/AnimationController/build"
  if $IS_ARCH; then install_pkgs cmake; fi
  if ! $IS_ARCH && command -v nix-shell >/dev/null 2>&1; then
    nix-shell "$shellnix" --run "bash '$script' '$NATIVE_PREFIX'" && ok=true
  elif command -v cmake >/dev/null 2>&1; then
    bash "$script" "$NATIVE_PREFIX" && ok=true
  else
    ui_warn "cmake is missing."
  fi

  if $ok; then
    if [ -n "$QT_NOW" ]; then state_set qt "$QT_NOW"; fi
    git_exclude ".config/quickshell/OozeShell/native/AnimationController/build/"
    RESTART_NEEDED=true
    ui_ok "Native core installed in $NATIVE_PREFIX/OozeShell/Native"
  else
    FAILED+=("native core (build)")
    ui_warn "The native core did not build. OozeShell still works in pure QML."
    if ! $IS_ARCH && command -v nix-shell >/dev/null 2>&1; then
      ui_more "On NixOS the Qt in native/shell.nix must be the SAME one quickshell uses."
      ui_more "Retry later with:  nix-shell $shellnix --run 'bash $script'"
    else
      ui_more "Retry later with:  bash $script"
    fi
  fi
}

# ── Links and permissions ──
create_symlink() {
  local source="$1" target="$2"

  if [ ! -e "$source" ]; then
    ui_err "Source does not exist: $source"
    return 0
  fi
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" != "$source" ]; then FOREIGN_LINKS+=("$target"); fi
    return 0
  fi
  if [ -e "$target" ]; then
    ui_warn "Target already exists (not a symlink): $target"
    if resolve_conflict "$target"; then
      mv "$target" "${target}.bak-${STAMP}"
      ui_ok "Backup: ${target}.bak-${STAMP}"
    else
      ui_more "Skipped (real file kept)."
      return 0
    fi
  fi
  ln -s "$source" "$target"
  ui_ok "Linked: $target -> $source"
}

link_configs() {
  local items=() item wm tool
  mapfile -t items < <(sed -n '/^config_items=(/,/^)/p' "$INSTALLER" | grep -o '"[^"]*"' | tr -d '"')
  if [ "${#items[@]}" -eq 0 ]; then
    ui_warn "Could not read config_items from install-oozenix.sh; link check skipped."
    return 0
  fi
  if $INSTALL_LEGACY; then items+=("swaync" "swayosd"); fi
  for wm in niri mango; do
    if [ -e "$DOTFILES/.config/$wm" ]; then items+=("$wm"); fi
  done

  mkdir -p "$HOME/.config" "$HOME/.local/bin"
  for item in "${items[@]}"; do
    create_symlink "$DOTFILES/.config/$item" "$HOME/.config/$item"
  done
  create_symlink "$DOTFILES/.config/VK-Th/themes" "$HOME/.config/vesktop/themes"
  create_symlink "$DOTFILES/.zshrc" "$HOME/.zshrc"
  create_symlink "$DOTFILES/random-fastfetch" "$HOME/.local/bin/random-fastfetch"
  if ! $IS_ARCH; then
    create_symlink "$DOTFILES/nix-rofi" "$HOME/.local/bin/nix-rofi"
  fi
  tool="$(oozeshell_tools)/oozeshell"
  if [ -f "$tool" ]; then
    chmod +x "$tool"
    create_symlink "$tool" "$HOME/.local/bin/oozeshell"
  fi

  ui_ok "Links verified"
  if [ "${#FOREIGN_LINKS[@]}" -gt 0 ]; then
    ui_info "Left alone (linked somewhere else, maybe Home Manager): ${FOREIGN_LINKS[*]}"
  fi
}

fix_permissions() {
  local f
  for f in "$DOTFILES/random-fastfetch" "$DOTFILES/OozeWalls/install.sh"; do
    if [ -f "$f" ]; then chmod +x "$f"; fi
  done
  if ! $IS_ARCH && [ -f "$DOTFILES/nix-rofi" ]; then chmod +x "$DOTFILES/nix-rofi"; fi
  find "$DOTFILES/.config" "$DOTFILES/OozeWalls" -type f \( -name '*.sh' -o -name '*.py' \) \
    -not -path '*/native/*/build/*' ! -perm -u+x -exec chmod +x {} + 2>/dev/null || true
  ui_ok "Scripts are executable"
}

migrate_ipc_binds() {
  local f legacy=() bak
  for f in \
    "$HOME/.config/hypr/modules/input/keybinds.lua" \
    "$HOME/.config/hypr/modules/startup/programs.lua" \
    "$HOME/.config/niri/modules/binds.kdl" \
    "$HOME/.config/mango/conf/keybinds.conf"; do
    [ -f "$f" ] || continue
    if grep -qE 'pacsearch|OozeShell-mango|OozeShell call apps|spawn "(qs|quickshell) ipc|,spawn,(qs|quickshell) ipc' "$f"; then
      legacy+=("$f")
    fi
  done
  if [ "${#legacy[@]}" -eq 0 ]; then
    ui_ok "Keybind IPC calls are current"
    return 0
  fi
  ui_warn "Legacy IPC calls found in: ${legacy[*]}"
  if ! ask_yes_no "Migrate them now?" y \
    "Only the IPC call syntax changes; a backup is saved in $BACKUP_DIR."; then
    ui_more "Skipped. Run install-oozenix.sh later: it migrates them too."
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  for f in "${legacy[@]}"; do
    bak="$BACKUP_DIR/$(basename "$f").bak-${STAMP}"
    cp -f "$f" "$bak"
    sed -i -E \
      -e 's/(call( --)? )pacsearch /\1nixsearch /' \
      -e 's#spawn "(qs|quickshell) ipc#spawn-sh "\1 ipc#' \
      -e 's#,spawn,(qs|quickshell) ipc#,spawn_shell,\1 ipc#' \
      -e 's#OozeShell-mango/shell\.qml#OozeShell/shell.qml#g' \
      -e 's#(qs|quickshell) ipc -p (/home/[^/ ]+|~|\$HOME)/\.config/quickshell/OozeShell call (--[[:space:]]+)?apps #quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- apps #g' \
      "$f"
    ui_ok "IPC calls updated in $f (backup: $bak)"
  done
  RESTART_NEEDED=true
}

update_fontconfig() {
  local src dst
  src="$(oozeshell_tools)/fonts/99-oozeshell-pixel.conf"
  dst="$HOME/.config/fontconfig/conf.d/99-oozeshell-pixel.conf"
  if ! $IS_ARCH || [ ! -f "$src" ]; then return 0; fi
  if ! cmp -s "$src" "$dst"; then
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    fc-cache -f >/dev/null 2>&1 || true
    ui_ok "fontconfig updated (icon fallback)"
  fi
}

# ── Environment ──
apply_env_lua() {
  local tmp qml_line
  qml_line='hl.env("QML_IMPORT_PATH", os.getenv("HOME") .. "/.local/share/oozeshell/qml")'

  if [ ! -f "$ENVLUA" ]; then
    ui_warn "env.lua not found: $ENVLUA"
    ui_more "Add this to your Hyprland session environment by hand if you use the native core:"
    ui_more "  $qml_line"
    return 0
  fi
  tmp="$(mktemp)"
  cp "$ENVLUA" "$tmp"

  if $IS_ARCH; then
    sed -i -E 's/^--[[:space:]]*(hl\.env\("ELECTRON_OZONE_PLATFORM_HINT", "auto"\).*)$/\1/' "$tmp"
    if $HAS_NVIDIA; then
      sed -i -E 's/^--[[:space:]]*(hl\.env\("LIBVA_DRIVER_NAME", "nvidia"\).*)$/\1/' "$tmp"
      sed -i -E 's/^--[[:space:]]*(hl\.env\("__GLX_VENDOR_LIBRARY_NAME", "nvidia"\).*)$/\1/' "$tmp"
    fi
  fi
  if [ -d "$NATIVE_PREFIX/OozeShell/Native" ] && ! grep -q 'QML_IMPORT_PATH' "$tmp"; then
    printf '\n-- OozeShell native core (added by install-oozenix.sh)\n%s\n' "$qml_line" >> "$tmp"
  fi

  if cmp -s "$tmp" "$ENVLUA"; then
    ui_ok "env.lua is current"
  else
    mkdir -p "$BACKUP_DIR"
    cp -f "$ENVLUA" "$BACKUP_DIR/env.lua.bak-${STAMP}"
    cat "$tmp" > "$ENVLUA"
    ENV_CHANGED=true
    ui_ok "env.lua re-applied (backup: $BACKUP_DIR/env.lua.bak-${STAMP})"
  fi
  rm -f "$tmp"
}

# ── Optional parts ──
update_oozewalls() {
  local dir="$DOTFILES/OozeWalls" ok=false
  if [ ! -f "$dir/Cargo.toml" ] || [ ! -x "$HOME/.local/bin/oozewalls" ]; then return 0; fi
  if ! $FORCE && ! changed_in "OozeWalls/"; then
    ui_ok "OozeWalls is current"
    return 0
  fi
  if ! ask_yes_no "OozeWalls changed. Rebuild it now?" y \
    "Written in Rust; takes a few minutes. The old binary keeps working if you say no."; then
    return 0
  fi

  chmod +x "$dir/install.sh"
  if $IS_ARCH; then
    install_pkgs wayland libxkbcommon mesa libglvnd fontconfig freetype2 \
      libx11 libxcursor libxrandr libxi xdg-desktop-portal xdg-desktop-portal-gtk
    if ! command -v cargo >/dev/null 2>&1; then install_pkgs rust; fi
  fi

  ui_task "Building the OozeWalls engine"
  if command -v cargo >/dev/null 2>&1; then
    bash "$dir/install.sh" && ok=true
  elif command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p cargo rustc gcc pkg-config --run "bash '$dir/install.sh'" && ok=true
  else
    ui_warn "cargo not found and no nix-shell available."
  fi

  if $ok; then
    ui_ok "OozeWalls rebuilt: $HOME/.local/bin/oozewalls"
  else
    FAILED+=("oozewalls (build)")
    ui_warn "OozeWalls did not build. Retry later with:  bash $dir/install.sh"
  fi
}

# ── Summary ──
summary() {
  local f
  if [ "${#FAILED[@]}" -gt 0 ]; then
    echo
    ui_warn "These steps did NOT complete:"
    for f in "${FAILED[@]}"; do echo "      - $f"; done
    ui_more "Check names with: pacman -Ss <name>  /  ${AUR_HELPER:-paru} -Ss <name>"
  fi
  ui_banner "Oozenix update complete"
  echo
  if [ "$OLD_HEAD" != "$NEW_HEAD" ]; then
    echo "Repository:     ${OLD_HEAD:0:7} -> ${NEW_HEAD:0:7}"
  fi
  if $STASH_KEPT; then
    echo "Local changes:  kept in the stash (see the warning above)"
  fi
  if $ENV_CHANGED; then
    echo "env.lua:        changed; log out and back in for the session environment to apply"
  fi
  if ! $IS_ARCH && changed_in "NixOSInstallation.md"; then
    echo "Dependencies:   the list changed; review $NIXOS_MD"
  fi
  if changed_in "update-oozenix.sh"; then
    echo "Updater:        this script changed in the update; run it once more to use the new steps"
  fi
  if changed_in "install-oozenix.sh"; then
    echo "Installer:      changed in the update; read the diff if you rely on its questions"
  fi
}

restart_shell() {
  local launch
  launch="$(oozeshell_tools)/ooze-launch.sh"
  if ! $RESTART_NEEDED; then return 0; fi
  if [ ! -f "$launch" ] || [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "Restart:        log out and back in (or run: bash $launch)"
    return 0
  fi
  if ask_yes_no "Reload Hyprland and restart OozeShell now?" n \
    "Closes and reopens the shell; your windows are not touched."; then
    if command -v hyprctl >/dev/null 2>&1; then hyprctl reload >/dev/null 2>&1 || true; fi
    setsid -f bash "$launch" >/dev/null 2>&1
    ui_ok "OozeShell restarting"
  else
    echo "Later:          hyprctl reload  ·  bash $launch"
  fi
}

# ── Main ──
main() {
  parse_args "$@"

  ui_banner "Oozenix / OozeShell" "Updater"

  ui_phase "Checking"
  pre_checks
  detect_distro
  snapshot_state
  fetch_remote

  if $CHECK; then
    if zip_changed; then ui_info "OozeShell.zip differs from the installed one."; fi
    if qt_changed; then ui_info "Qt changed ($QT_RECORDED -> $QT_NOW): the native core needs a rebuild."; fi
    if [ "$BEHIND" -gt 0 ] || zip_changed || qt_changed; then
      ui_info "Update available. Run update-oozenix.sh to apply it."
    else
      ui_ok "Already up to date."
    fi
    exit 0
  fi
  if nothing_to_do; then
    ui_ok "Already up to date."
    exit 0
  fi

  ui_phase "Repository"
  sync_repo
  if $PULL_FAILED; then
    ui_err "The repository was not updated; the rest of the update was skipped."
    exit 1
  fi

  if $IS_ARCH; then
    ui_phase "Arch Linux"
    system_update
    update_packages
    update_tachidesk_ctl
  fi

  ui_phase "OozeShell"
  update_oozeshell
  update_native

  ui_phase "Links and permissions"
  link_configs
  fix_permissions
  migrate_ipc_binds
  update_fontconfig

  ui_phase "Environment"
  apply_env_lua
  update_oozewalls

  if ! $EXTRACT_FAILED && [ -n "$CUR_ZIP" ]; then state_set zip "$CUR_ZIP"; fi
  if [ -z "$(state_get qt)" ] && [ -n "$QT_NOW" ]; then state_set qt "$QT_NOW"; fi

  summary
  restart_shell
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
  exit 0
fi
