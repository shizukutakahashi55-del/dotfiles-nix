# How `install-oozenix.sh` works

This page explains the installer block by block, so you can read the script
without guessing what each part is for. The script itself only keeps short
block titles (`# ── Name ──`); everything else is explained here.

If you only want to **use** the installer, the [README](README.md#install) is
enough. Read this page if you want to know what it will do to your system,
fix something, or add a package.

---

## The big picture

The script runs top to bottom in five stages:

```text
1. Setup            variables, helper functions
2. Pre-checks       not root? dotfiles folder exists? is this an update?
3. Distro branch    Arch  → installs packages, builds optional parts
                    Other → writes a dependency list (NixOSInstallation.md)
4. Linking          symlinks, executable permissions, config migrations
5. Optional extras  OozeWalls, env.lua edits, git tweaks, final summary
```

Rules the script follows everywhere:

* It never runs as root. It calls `sudo` only for the few commands that need it.
* It asks before anything invasive (system update, services, optional apps).
* It never deletes your files. Anything it replaces is moved to a
  `.bak-<timestamp>` copy first.
* A failed package does not stop the install. It is remembered in a list and
  shown in the final summary.

---

## Stage 1 — Setup

### Variables

| Variable | Meaning |
| --- | --- |
| `DOTFILES` | The repository folder. Always `~/dotfiles`. |
| `QS_DIR` | Where Quickshell configs live inside the repo (`.config/quickshell`). |
| `STAMP` | Date and time of this run. Used to name backups so they never collide. |
| `BACKUP_DIR` | Where an old OozeShell copy is moved (`~/.local/share/oozeshell/backups`). |
| `IS_ARCH`, `IS_UPDATE`, `HAS_NVIDIA`, `INSTALL_LEGACY` | Yes/no answers collected during the run. |
| `NATIVE_OK`, `OOZEWALLS_OK`, `SUWAYOMI_OK` | Set to `true` only if that optional part really got installed. The final summary reads them. |
| `AUR_HELPER` | `paru` or `yay` if found, empty otherwise. |
| `FAILED` | List of packages or steps that did not work. |

### Helper functions

| Function | What it does |
| --- | --- |
| `ask_yes_no` | Asks a question and repeats until the answer starts with `y` or `n`. |
| `create_symlink` | Links a repository file into your home. Skips if already correct, replaces a wrong link, and asks before moving a real file out of the way. |
| `oozeshell_tools`, `oozeshell_services` | Find the `Tools` and `Services` folders inside OozeShell. Older OozeShell zips used different folder names (`tools`, and services at the top level). These helpers check which layout is present, so both old and new zips install correctly. They are called after the zip is extracted. |
| `extract_oozeshell` | Moves the current `OozeShell` folder to the backups directory, unzips the new one, and removes any stale native build folder. |
| `build_native` | Builds the optional C++ animation core and records success in `NATIVE_OK`. |
| `maybe_build_native_other` | Same, for non-Arch systems. Uses `nix-shell` if available. |
| `install_oozewalls` | Offers to build the OozeWalls wallpaper engine (Rust). |

---

## Stage 2 — Pre-checks

1. **Root check.** Stops if you are root. Symlinks would land in `/root` and
   `makepkg` refuses to run as root anyway.
2. **Dotfiles folder.** Stops if `~/dotfiles` does not exist.
3. **Update detection.** If `~/.config/hypr` is already a link into the
   repository, the script switches to *update mode* (see Stage 5).
4. **Distro question.** "Are you using Arch Linux?" decides the branch. If you
   say yes but `pacman` or `/etc/arch-release` are missing, it warns you and
   asks whether to continue.
5. **`OozeShell.zip`.** Stops if `~/dotfiles/OozeShell.zip` is missing.

---

## Stage 3a — Arch branch

Runs in this order. Each item is a block in the script.

| Block | What happens | Asks first? |
| --- | --- | --- |
| **AUR helper** | Looks for `paru` or `yay`. If none, offers to install `paru-bin`. Without a helper, AUR-only packages end up in the failed list. | Yes |
| **System update** | `sudo pacman -Syu`. Recommended on an old install. | Yes |
| **Package helpers** | Defines the install functions (see below). | No |
| **Suwayomi helpers** | Defines the functions that set up the optional Suwayomi manga server. | No |
| **Base packages** | Installs the `BASE` list, then `quickshell` and `awww`. | No |
| **Clipboard tools** | Makes sure `wl-copy`, `wl-paste` and `cliphist` exist. | No |
| **Terminal** | Menu to pick `foot`, `kitty`, `alacritty`, `wezterm` or `ghostty`. | Menu |
| **Services** | Enables `NetworkManager`, `bluetooth`, `power-profiles-daemon`. | Yes |
| **Optional packages** | Waybar, and the legacy `swaync` / `swayosd` / `wlogout`. | Yes |
| **Extras** | Dev tools, gaming and utilities bundle. | Yes |
| **Suwayomi** | Installs the server and a `tachidesk` control command. | Yes |
| **Nvidia** | Only records your answer. `env.lua` is edited later. | Yes |
| **Unzip OozeShell** | Calls `extract_oozeshell`. | No |
| **Fonts** | Copies the fontconfig fallback so icons never show as empty squares. | No |
| **Native core** | Installs `cmake` and builds the C++ module. | Yes |

### The package helpers

| Function | Behavior |
| --- | --- |
| `pkg_installed` | True if pacman already has the package. |
| `install_pkgs` | Sorts a list into *official repo* and *AUR*, installs each group in one batch, and **retries one by one** if the batch fails so a single bad name does not block the rest. |
| `install_first` | Takes alternatives (for example `quickshell quickshell-git`) and installs the first one that works. |
| `check_hyprland` | Warns if Hyprland is older than 0.55, because the Lua config needs 0.55 or newer. |

### What `BASE` contains and why

| Group | Packages | Used for |
| --- | --- | --- |
| Build tools | `base-devel git curl unzip zip` | Building AUR packages and the native core. |
| Shell and scripts | `zsh jq python` | `.zshrc`, JSON handling, `palette-apply.py` (needs Python 3.11+). |
| Compositor | `hyprland hyprpaper hypridle hyprlock hyprpolkitagent hyprshot hyprsunset hyprshutdown hyprsysteminfo` | The window manager and its helpers. |
| Portals | `xdg-desktop-portal` + `-hyprland` + `-gtk` | Screen sharing and file pickers. |
| Qt | `qt6-base qt6-declarative qt6-svg qt6-shadertools qt6ct` | What Quickshell draws with. |
| Audio | `pipewire pipewire-pulse wireplumber libpulse` | Sound. `libpulse` provides `pactl`, used by screen recording to choose the audio device. |
| Hardware | `brightnessctl power-profiles-daemon upower` | Brightness, power modes, battery. |
| Network and Bluetooth | `networkmanager network-manager-applet bluez bluez-utils blueman` | Wi-Fi and Bluetooth menus. |
| Media | `mpv mpvpaper ffmpeg socat` | Live wallpapers, video optimizing, screen recording merge. |
| Desktop utilities | `xdg-utils xdg-user-dirs libnotify imagemagick wtype wev` | Opening links, finding Pictures/Videos folders, notifications. |
| Capture | `grim slurp wf-recorder` | Screenshots and screen recording. |
| Audio tools | `cava pavucontrol qpwgraph` | Visualizer, volume control, routing graph. |
| Misc | `fastfetch rofi tmux matugen` | System info, alternative launcher, launcher sessions, palette from wallpaper. |
| Fonts | JetBrainsMono Nerd Font, Symbols Nerd Font Mono, Noto Color Emoji, Silkscreen, DotGothic16, VT323 | Icons, emoji and the pixel theme. |

After the base install the script also runs `xdg-user-dirs-update`, which
creates your standard folders (Pictures, Videos…) if they do not exist yet.
Screenshots and recordings are saved there.

**To add a package:** put its name in the `BASE` list (or `EXTRAS` for the
optional bundle). `install_pkgs` finds out by itself whether it is in the
official repos or the AUR.

### Packages that are NOT installed on purpose

| Package | Why it is left out |
| --- | --- |
| `aria2` | Optional. Makes online wallpaper downloads faster. Without it `curl` is used. |
| `libsecret` + a keyring | Optional. Stores AI agent API keys in your keyring. Without it they go to an encrypted file. |
| `nvidia-utils` | Comes with your NVIDIA driver and gives `nvidia-smi` for GPU stats. Installing it here could clash with legacy driver packages. |
| `niri`, `mango` | Alternative compositors. OozeShell detects them if you install them yourself. |
| `claude`, `gemini`, `codex`, `ollama` | Optional AI agent back-ends. Install the ones you use. |

---

## Stage 3b — Other distributions

For anything that is not Arch the script treats the system as NixOS and
**installs no packages**.

1. Unzips OozeShell. If `unzip` is missing and `nix-shell` exists, it offers a
   temporary `nix-shell` with `unzip`; otherwise it stops and tells you to
   install `unzip`.
2. Offers to build the native core through `nix-shell`.
3. Asks whether to link the legacy `swaync` / `swayosd` configs.
4. Writes `NixOSInstallation.md`. The text lives inside the script, so keep it
   identical to the `NixOSInstallation.md` in the repository.

---

## Stage 4 — Linking

### Symlinks

Each name in `config_items` is linked from `~/dotfiles/.config/<name>` to
`~/.config/<name>`. Extra links: `.zshrc`, `random-fastfetch`, the Vesktop
theme folder, `nix-rofi` (non-Arch only), and `niri` / `mango` if their
folders exist in the repository. The behavior for already existing targets is
the table in the README.

### Executable permissions

An explicit list of scripts gets `chmod +x`. Missing files are reported but do
not stop the run. Afterwards a **safety sweep** runs over every `*.sh` and
`*.py` inside OozeShell and makes them executable. This covers scripts added
in the future, and zips that were rebuilt on a system that drops permission
bits.

### Keybind migration (`migrate_ipc_binds`)

Older versions of the dotfiles called IPC names or paths that no longer
exist. The script checks these files and fixes them in place, keeping a
`.bak-<timestamp>` copy:

* `hypr/modules/input/keybinds.lua`
* `hypr/modules/startup/programs.lua`
* `niri/modules/binds.kdl`
* `mango/conf/keybinds.conf`

| Old form | Replaced by |
| --- | --- |
| IPC target `pacsearch` | `nixsearch` (it detects Arch by itself) |
| `.../OozeShell-mango/shell.qml` | `.../OozeShell/shell.qml` |
| `OozeShell call apps ...` with a hard-coded `/home/<user>` path, no `shell.qml` and no `--` | `~/.config/quickshell/OozeShell/shell.qml call -- apps ...` |
| niri `spawn "qs ipc ..."` and mango `,spawn,qs ipc ...` | `spawn-sh` and `spawn_shell`, because plain `spawn` runs no shell and `~` would never be expanded |

### The `oozeshell` command

`Tools/oozeshell` is linked to `~/.local/bin/oozeshell`. It is a short way to
call the IPC (`oozeshell apps open browser`). The script warns you if
`~/.local/bin` is not in your `PATH`.

---

## Stage 5 — Optional extras and summary

| Block | What happens |
| --- | --- |
| **OozeWalls engine** | Asks, then installs the runtime libraries and Rust on Arch, builds `OozeWalls/` and copies `oozewalls` and `oozewalls-gui` to `~/.local/bin`. |
| **Arch: env.lua** | Backs up `hypr/modules/system/env.lua`, enables the Electron hint line and, if you said yes to NVIDIA, the two NVIDIA lines. It works by removing the leading `--` of commented lines. |
| **Native core: QML_IMPORT_PATH** | If the native build worked, adds one line to `env.lua` so Quickshell can find the module. You must log out and back in once. |
| **Update mode** | Only when an existing install was detected. Tells git to ignore local changes in `hypr/modules/appearance/autogen`, because OozeShell regenerates those files. The command to undo it is printed. |
| **Summary** | Lists everything in `FAILED`, then prints how to start OozeShell and which optional parts are active. |

---

## Files the installer can create or change

| Path | When |
| --- | --- |
| `~/.config/<name>` | Symlinks, always. |
| `<target>.bak-<timestamp>` | A real file or folder was in the way and you said yes to move it. |
| `~/.local/share/oozeshell/backups/OozeShell.bak-<timestamp>` | A previous OozeShell copy. |
| `~/.local/share/oozeshell/qml/OozeShell/Native` | Native core build. |
| `~/.config/fontconfig/conf.d/99-oozeshell-pixel.conf` | Arch, icon fallback. |
| `~/.config/hypr/modules/system/env.lua` (+ `.bak-<timestamp>`) | Arch, and native core. |
| `~/.local/bin/oozeshell`, `oozewalls`, `oozewalls-gui`, `random-fastfetch` | Links and builds. |
| `/usr/local/bin/tachidesk` and `~/.config/systemd/user/tachidesk.service` | Only if you install Suwayomi. |
| `~/dotfiles/SuwayomiSetup.md` | Only if you skip Suwayomi. |
| `~/dotfiles/NixOSInstallation.md` | Non-Arch branch. |
