# Oozenix Dotfiles Beta

A ready-made desktop for Linux. It uses **Hyprland** (a window manager for Wayland) and **OozeShell**, a custom shell built with Quickshell and Qt6 that gives you the top bar, app launcher, notifications, lock screen, wallpaper picker, dock, media controls, power menu and most system panels in one consistent look.

It works on **NixOS** (main target) and **Arch Linux**.

![Desktop](screenshots/Desktop.png)

> **Read this before you start**
> * These are my personal settings. Expect to adjust your monitors, GPU variables, keyboard layout and a few paths. The Hyprland config is written for an **NVIDIA** machine.
> * The Hyprland config is a Lua file (`hyprland.lua`) and needs **Hyprland 0.55 or newer**.
> * On NixOS the easiest way is to pair these dotfiles with [nix-home](https://github.com/shizukutakahashi55-del/nix-home), which already provides every package, service and font.
> * Installing replaces your current desktop settings with links to this repository. The installer asks before touching anything that already exists, and keeps a backup, but a fresh install or a spare user account is the safest place to try it.

<details>
<summary><b>New to Linux? Words used in this guide (click to open)</b></summary>

| Word | Meaning |
| --- | --- |
| **Terminal** | A window where you type commands. Lines starting with `$` in other guides are typed there; here you just copy the command. |
| **Dotfiles** | Configuration files for your programs. Their names often start with a dot, like `.zshrc`. This repository is a collection of them. |
| **Hyprland** | The program that draws and arranges your windows (a *compositor*). It replaces desktops like GNOME or KDE. |
| **Wayland** | The modern way Linux draws graphics on screen. Hyprland only works on Wayland. |
| **Quickshell / OozeShell** | Quickshell is a toolkit for building desktop shells. OozeShell is the shell built with it in this repository: bar, launcher, notifications and so on. |
| **Package** | An installable program. A *package manager* (`pacman` on Arch, `nix` on NixOS) installs them. |
| **AUR** | The Arch User Repository: extra packages made by the community. You need a helper like `paru` or `yay` to use it. The installer can set up `paru` for you. |
| **Symlink** | A shortcut file. Your `~/.config/hypr` becomes a shortcut to the folder inside this repository, so editing one edits the other. |
| **`~`** | Shortcut for your home folder, for example `/home/yourname`. |
| **`sudo`** | Runs one command with administrator rights. It asks for your password. |
| **TTY** | A text-only screen. You reach one with `Ctrl+Alt+F3` and leave it with `Ctrl+Alt+F1` or `F2`. |
| **Log out / log in** | Closing your session and starting it again. Some changes only apply after this. |

</details>

---

## Contents

[Supported systems](#supported-systems) · [Install](#install) · [Installer questions](#installer-questions-and-what-to-answer) · [What gets linked](#what-gets-linked) · [Dependencies](#dependencies) · [OozeShell](#oozeshell) · [IPC](#controlling-oozeshell-ipc) · [Theming and wallpapers](#theming-and-wallpapers) · [Waybar](#waybar) · [Optional components](#optional-components) · [Updating](#updating) · [Uninstall](#uninstall) · [Troubleshooting](#troubleshooting) · [Repository layout](#repository-layout)

---

## Supported systems

| System | Support |
| --- | --- |
| **NixOS** | Main target. Package search uses `nix-search`. |
| **Arch Linux** | Supported. The installer installs the dependencies. Package search uses pacman + AUR. |
| **Other distros** | Not supported. The installer takes the NixOS branch and writes `NixOSInstallation.md` with the dependency list so you can adapt it by hand. |

**Not sure what you use?** Run this in a terminal:

```bash
cat /etc/os-release
```

Look at the `NAME=` line.

---

## Install

### Before you begin

You need:

* A working Arch Linux or NixOS system with internet access and a normal user account (not `root`) that can use `sudo`.
* About 15 to 30 minutes. The system update and the optional builds are the slow parts.
* A computer you can log out of: you will restart your session at the end.

If you have not installed Arch yet, follow the [official Arch installation guide](https://wiki.archlinux.org/title/Installation_guide) first (the `archinstall` tool on the live ISO is the simplest way), then come back here.

### Step 1. Open a terminal

On a fresh Arch system you already have a text login. On another desktop, search for "Terminal" in your applications menu. Every command below is typed in the terminal and run with `Enter`.

### Step 2. Install git

`git` downloads the repository. Skip this if `git --version` already prints a version.

```bash
sudo pacman -S --needed git
```

On NixOS, use `nix-shell -p git` for a temporary git.

### Step 3. Download the dotfiles into `~/dotfiles`

The installer expects exactly this folder name and place.

```bash
git clone https://github.com/shizukutakahashi55-del/dotfiles-nix.git ~/dotfiles
cd ~/dotfiles
```

### Step 4. Check what is specific to your machine

Open these in a text editor (`nano ~/dotfiles/.config/hypr/hyprland.lua` works in a terminal) and adjust them if needed. You can also do it after installing.

* Monitors: `hypr/modules/hardware`
* NVIDIA variables, keyboard layout, startup apps, keybinds and terminal.

Paths use `$HOME`, so you do not need to put your username anywhere.

### Step 5. Run the installer

Run it as your normal user. It refuses to run as root and uses `sudo` only where needed.

```bash
chmod +x install-oozenix.sh
./install-oozenix.sh
```

It asks questions along the way. If you are unsure about one, see [Installer questions](#installer-questions-and-what-to-answer). When it ends, it prints a summary and lists anything that failed to install.

### Step 6. Log out and start Hyprland

1. Log out of your current session (or reboot).
2. At the login screen, choose the **Hyprland** session. If you have no login screen, log in on the text console and run `Hyprland` (never with `sudo`).
3. OozeShell starts by itself from Hyprland's startup module.

To start or restart OozeShell by hand from a terminal:

```bash
quickshell -c OozeShell
```

### Step 7. First things to try

* Press `SUPER+I` to see every keybind. (`SUPER` is the key with the Windows or Command logo.)
* Press `SUPER+L` to choose your monitor and `SUPER+G` to choose the language.
* Put some pictures in `~/Pictures/Wallpapers` and open the wallpaper selector.
* Open **Settings** to change the bar, style, colors and fonts.

---

### What the installer does

It is interactive and asks before anything invasive. On every system it:

1. Extracts `OozeShell.zip` into `.config/quickshell/OozeShell`. A previous copy is moved to `~/.local/share/oozeshell/backups/`, never deleted.
2. Creates the symlinks and makes the scripts executable.

On **Arch** it also: checks for an AUR helper (and offers `paru`), optionally updates the system, installs the base dependencies (retrying one by one if a batch fails), installs `quickshell` and `awww`, installs the terminal you choose, optionally enables services, Waybar, legacy tools, extras and Suwayomi, optionally builds the OozeWalls engine, and enables the NVIDIA and Electron variables in `env.lua`.

On **other distros** it only writes `NixOSInstallation.md` and links `nix-rofi`. No packages are installed.

A block-by-block explanation of the script, with the full package list and the reason for each package, is in **[INSTALLER.md](INSTALLER.md)**.

---

## Installer questions and what to answer

The installer is written in English and expects `y` (yes) or `n` (no). If you are unsure, the "If unsure" column is a safe choice.

| Question | If unsure | Notes |
| --- | --- | --- |
| Are you using Arch Linux? | `y` on Arch, `n` otherwise | `n` means no packages are installed. |
| Install `paru` now? | `y` | Several packages (`matugen`, `mpvpaper`, `awww`, some fonts) can live in the AUR and need a helper. |
| Run a full system update first? | `y` | Arch does not support updating only some packages, so a fresh update avoids version problems. It can take a while. |
| Choose your terminal (menu) | Any | `foot` is light, `kitty` is beginner friendly. Pick "Already installed" if you have one. |
| Enable NetworkManager, bluetooth and power-profiles-daemon? | `y` | Say `n` only if you use `iwd` or another network tool. |
| Install Waybar? | `n` | Optional second bar. You can install it later. |
| Install swaync, swayosd and wlogout? | `n` | OozeShell already replaces them. |
| Install the extras bundle? | `n` | Large download: dev tools, gaming, utilities. |
| Install Suwayomi server? | `n` | Only if you want the manga server. Steps for later go to `SuwayomiSetup.md`. |
| Do you use an Nvidia GPU? | Check first | Run `lspci \| grep -i nvidia`. If it prints a line, say `y`. |
| Build the native animation core? | `y` | About a minute. OozeShell works without it. |
| Build and install the OozeWalls engine? | `n` | Optional live-wallpaper engine, takes a few minutes. |
| Move an existing file to `.bak-<timestamp>`? | `y` | Your original is kept next to it. Answer `n` to keep yours and skip that item. |

---

## What gets linked

Everything is a symlink into `~/dotfiles/.config`, so editing `~/.config/hypr/` edits the repository directly.

| Always | Only if you say yes to "legacy tools" | Only on non-Arch |
| --- | --- | --- |
| `alacritty` `cava` `dolphin` `fastfetch` `foot` `ghostty` `hypr` `kitty` `matugen` `nvim` `quickshell` `rofi` `wezterm` `yazi` `waybar` `starship.toml` `.zshrc` | `swaync` `swayosd` | `~/.local/bin/nix-rofi` |

Also linked: `niri` and `mango` (when present), and `VK-Th/themes` → `~/.config/vesktop/themes`.

What happens when something already exists at the destination:

| Situation at the target | Result |
| --- | --- |
| Nothing there | Link created. |
| Link to the right place | Left alone. |
| Link to somewhere else | Replaced. |
| Real file or directory | Asks to move it to `<target>.bak-<timestamp>`. Answer `n` to skip that item. |

`git-update` is not linked automatically; see [Updating](#updating).

---

## Dependencies

On Arch the installer handles all of this. On NixOS use nix-home or `NixOSInstallation.md`.

| Group | Packages |
| --- | --- |
| Compositor | `hyprland` (≥ 0.55), `hyprpaper`, `hypridle`, `hyprlock`, `hyprpolkitagent`, `hyprshot`, `hyprsunset`, `hyprshutdown`, `hyprsysteminfo`, `xdg-desktop-portal` (+ `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`) |
| Shell | `quickshell`, Qt6 (`qt6-base`, `qt6-declarative`, `qt6-svg`, `qt6-shadertools`, `qt6ct`) |
| Audio | `pipewire`, `pipewire-pulse`, `wireplumber`, `libpulse` (gives `pactl`), `pavucontrol`, `qpwgraph` |
| Hardware | `brightnessctl`, `power-profiles-daemon`, `upower` |
| Network / Bluetooth | `networkmanager` + applet, `bluez`, `bluez-utils`, `blueman` |
| Media | `playerctl`, `mpv`, `mpvpaper`, `ffmpeg`, `cava` |
| Screenshots / recording | `grim`, `slurp`, `wf-recorder` |
| Wallpaper / theming | `awww`, `imagemagick`, `matugen` |
| Utilities | `socat`, `jq`, `wl-clipboard`, `cliphist`, `xdg-utils`, `xdg-user-dirs`, `libnotify`, `wtype`, `wev`, `fastfetch`, `tmux`, `curl`, `python` (3.11 or newer), `zsh`, `rofi` |
| Fonts | JetBrainsMono Nerd Font, Symbols Nerd Font Mono, Noto Color Emoji |
| Terminal | one of foot, kitty, alacritty, wezterm, ghostty |

**Optional:**

* `waybar`, `swaync`, `swayosd`, `wlogout`.
* `nix-search` (NixOS package search).
* `aria2` for faster online wallpaper downloads (without it `curl` is used).
* `libsecret` and a keyring (for example `gnome-keyring`) to store AI agent API keys safely. Without them the keys go to an encrypted file.
* `nvidia-smi` (comes with the NVIDIA driver) for GPU stats.
* Pixel fonts for the CoOzey theme: Pixelify Sans, Jersey 10, Silkscreen, VT323, DotGothic16. The NixOS snippet is in `OozeShell/Tools/fonts/fonts.nix.example`. On Arch only Silkscreen, VT323 and DotGothic16 are installed, so Pixelify Sans and Jersey 10 fall back to the Nerd Font.
* An extras bundle on Arch (yazi, neovim, starship, gaming tools and more).
* Niri or MangoWM. OozeShell detects them on its own. Niri works fine; MangoWM is still in progress, and I am a bit limited testing it with v0.17.4 on NixOS.

---

## OozeShell

**Modes:** *Bar* (top, bottom, left or right, optionally floating), *Islands* (no bar background, popups grow from their island) and *Pill + Dashboard* (compact pill that opens a full dashboard). Two styles, **OozeSoft** and **CoOzey**, each in light and dark, and some extra palettes.

**Main features**

* Taskbar, tray, workspaces, clock, privacy indicators, battery, brightness, and a floating **Dock**.
* **Dashboard**: overview, performance, audio, calendar, media, power, quick access.
* **Launcher** (apps, windows, run, files, calculator, tmux sessions) and **Overview** with live window previews.
* **Package search**: `nix-search` on NixOS, pacman + AUR on Arch, with an Installed view (`Ctrl+L`) and uninstall (`Ctrl+R`) on Arch.
* Notification center with Do Not Disturb, **Agenda** with to-dos and alarms, clipboard history.
* **Wallpaper selector** with static and live video wallpapers, online sources, and palette extraction through Matugen.
* **Screenshots and screen recording** (zone or full screen, with pause).
* Media (MPRIS), audio menus and **OozeAudio** routing, network, Bluetooth and power-profile menus.
* **OozeLock**: native lock screen (`ext-session-lock-v1` + PAM), replaces `hyprlock`.
* OSDs, power menu, monitor selector and editor, keybinds cheatsheet.
* **Advanced Settings** with a searchable registry; appearance controls generate Hyprland theme files.
* Optional AI agent chat bubble (API providers, installed CLIs, or a local `ollama`).
* Languages: English, Español.

**Default keybinds**

| Keys | Action |
| --- | --- |
| `SUPER+I` | Keybinds cheatsheet |
| `SUPER+L` | Monitor picker |
| `SUPER+G` | Language picker |
| `SUPER+U` | Package search |

The source of truth is `hypr/modules/input/keybinds.lua`.

**Sanity check after editing the shell:**

```bash
cd ~/.config/quickshell/OozeShell
bash Tools/check.sh
```

---

## Controlling OozeShell (IPC)

IPC is a way to send commands to the running shell, for example from a keybind or a script. The long form is:

```bash
quickshell ipc -c OozeShell call <target> <function> [args]
```

There is also a short command, installed by the installer: `oozeshell list` shows every target, and `oozeshell apps open browser` is an example call.

| Target | Functions |
| --- | --- |
| `bar` | `position top\|bottom\|left\|right`, `togglePosition`, `floating true\|false`, `toggleFloating`, `islands`, `pill`, `togglePill`, `get` |
| `corners` | `toggle`, `set true\|false`, `get` |
| `settings` | `toggle`, `open`, `close`, `get` |
| `theme` | `mode light\|dark`, `toggle`, `style cozy\|soft`, `styleGet`, `softfont` |
| `appearance` | `toggle`, `get`, `set <key> <value>` |
| `launcher` | `toggle`, `open <apps\|windows\|run\|files>`, `close` |
| `nixsearch` | `toggle`, `open <query>`, `installed` (Arch), `close` |
| `overview`, `agenda`, `powermenu`, `clipboard` | `toggle`, `open`, `close` |
| `menu`, `network`, `bluetooth`, `mpris`, `keybinds` | `toggle` |
| `audio` | `toggle`, `raise`, `lower`, `mute`, `micToggle`, `micRaise`, `micLower` |
| `notify` | `toggle`, `show <text>`, `toggleDnd`, `enableDnd`, `disableDnd`, `isDnd`, `clear` |
| `toggleWalls` | `handle` |
| `screenshot` | `areaCopy`, `areaSave`, `fullSave` |
| `record` | `toggleArea`, `toggleScreen`, `startArea`, `startScreen`, `stop`, `pause`, `resume`, `togglePause`, `cancel`, `status` |
| `lock` | `lock`, `locked` |
| `monitor` | `set <name\|auto>`, `get`, `current`, `list`, `togglePicker` |
| `lang` | `set <code>`, `get`, `list`, `togglePicker` |
| `keyboardlayout` | `next` |
| `caps`, `layoutosd` | `show` |

The package search target is called `nixsearch` on every system, so the same keybind works everywhere.

---

## Theming and wallpapers

Matugen generates colors from the current wallpaper and themes Hyprland, OozeShell, Waybar, terminals, Cava, Starship, Yazi, Vesktop and more.

```text
~/.config/matugen/config.toml      main configuration
~/.config/matugen/templates/       one template per app
```

Wallpapers are read from `~/Pictures/Wallpapers` (create it if missing). Static ones use `awww`; video ones use `mpvpaper`, and Matugen takes the palette from one extracted frame. The lock screen wallpaper is set in **Advanced Settings → General**.

Screenshots are saved in your Pictures folder (`Screenshots`) and recordings in your Videos folder (`Recordings`). You can change both in **Advanced Settings → Captures & recording**.

---

## Waybar

OozeShell can use Waybar instead of its own bar: **Settings → Bar → Waybar** (horizontal bar only, not Pill). The option is disabled until `waybar` is installed.

How it is wired:

* `waybar/waybar-launcher.sh` is started by OozeShell and keeps a single Waybar alive. It picks the config for the active compositor (`config.jsonc`, `config-niri.jsonc` or `config-mango.jsonc`), restarts Waybar if it crashes, and shuts it down when you switch back to the OozeShell bar.
* On every wallpaper change, Matugen rewrites `waybar/style.css` and runs `matugen/scripts/reload-waybar.sh`, which only sends `SIGUSR2` to that Waybar so it reloads the colors in place. It never starts or kills Waybar itself.
* Each reload is logged in `$XDG_RUNTIME_DIR/waybar-ctl/reload.log`.

**Static themes** live in `waybar/themes/` and are applied with `waybar/themes/waybar-theme-switcher.sh`. They write the same `style.css` as Matugen, so Matugen overwrites them on the next wallpaper change. To keep a static theme, disable `[templates.waybar]` in `~/.config/matugen/config.toml`.

---

## Optional components

You can skip all of these. OozeShell works without them.

**Native animation core (C++).** With it, animation math runs natively; without it everything still works in plain QML.

```bash
bash ~/.config/quickshell/OozeShell/Tools/build-native.sh
```

The installer offers to build it. Quickshell finds it through `QML_IMPORT_PATH`, which the installer adds to `env.lua`; log out and back in once. When active, the OozeShell log says `[theme] núcleo nativo: activo`. It needs `cmake` and a C++17 compiler. On NixOS use `nix-shell native/shell.nix --run 'bash Tools/build-native.sh'`, and make sure that shell's Qt is the same one `quickshell` uses.

**Suwayomi (Arch).** A manga server. The installer can install `suwayomi-server-bin`, create a `tachidesk.service` user unit and a `tachidesk` command (`start|stop|restart|status|enable|disable`) in `/usr/local/bin`. OozeShell controls it from **Settings → Services**. It does not start at boot. If you skip it, the steps are written to `SuwayomiSetup.md`.

**OozeWalls (live-wallpaper engine).** The installer can build `OozeWalls/` (Rust) and install `oozewalls` and `oozewalls-gui` in `~/.local/bin`, plus a launcher entry. On Arch it also installs the runtime libraries and `cargo`/`rustc`; the folder picker of the GUI needs `xdg-desktop-portal` and a FileChooser backend. On NixOS the same engine ships as a Home Manager module (`OozeWalls/hm-module.nix`). Pick it in **Settings → Wallpapers** (static and live engine `oozewalls`). OozeShell restores the saved wallpaper on start, so no extra `exec-once` is needed.

---

## Updating

There are three ways, from easiest to most manual.

### 1. `update-oozenix.sh` (recommended)

Updates an existing install without repeating the installer questions. Run it as your normal user:

```bash
cd ~/dotfiles
chmod +x update-oozenix.sh
./update-oozenix.sh
```

It:

1. Fetches the remote and lists the new commits. Your local changes are set aside (stash), the repository is updated, and they are re-applied. If the branch diverged it offers a rebase.
2. On Arch: optionally updates the system, installs packages added since your last run, and refreshes the `tachidesk` command if you have it.
3. Extracts `OozeShell.zip` when it changed (the old folder goes to `~/.local/share/oozeshell/backups/`) and rebuilds the native core if the shell or Qt changed.
4. Checks links and permissions, migrates old IPC calls in your keybinds (with a backup), and re-applies the `env.lua` changes.
5. Rebuilds OozeWalls if its code changed, then offers to restart OozeShell.

| Option | Effect |
| --- | --- |
| `--check` | Only report whether an update is available. |
| `--system` | Also run a full system update (Arch). |
| `--force` | Redo extraction, native build and link checks even without changes. |
| `--replace` / `--keep` | Back up and replace, or keep, real files that block a link, without asking. |
| `-y`, `--yes` | Never ask; use the safe default for every question. |

### 2. By hand

Look at what you changed locally with `git status && git diff`, then choose one:

* **Keep your local changes:** commit them or run `git stash`, then `git pull` (and `git stash pop` if you stashed).
* **Drop one local change:** `git checkout -- <file>`, then `git pull`.
* **Discard everything local** (**this deletes all uncommitted work**): `git fetch origin && git reset --hard origin/main`.

Then run `bash install-oozenix.sh` again. In update mode it replaces the OozeShell folder (the old one goes to the backups directory) and tells git to ignore `hypr/modules/appearance/autogen`, which OozeShell regenerates. On Arch it also re-applies the `env.lua` changes, which will show up as local modifications.

---
##  `git-update` command

Not linked automatically. Helper to upload your git changes on your repositories. To use it from anywhere:

```bash
chmod +x ~/dotfiles/git-update
ln -s ~/dotfiles/git-update ~/.local/bin/git-update
```
It does the git add, git commit and push with one command. How to used it:

```bash
git-update -Your comment here
```
---

## Uninstall

Removing a symlink does not delete the repository. Check where a link points first (`readlink -f ~/.config/hypr`), then:

```bash
rm ~/.config/{alacritty,cava,dolphin,fastfetch,foot,ghostty,hypr,kitty,matugen,nvim,quickshell,wezterm,yazi,waybar,rofi,starship.toml} \
   ~/.config/vesktop/themes ~/.zshrc
rm -f ~/.config/{swaync,swayosd,niri,mango} ~/.local/bin/nix-rofi
```

Only remove paths that are symlinks into this repository. Backups (`*.bak-<timestamp>`) are never touched; restore one by renaming it back.

---

## Troubleshooting

When something fails, the first useful step is almost always to **run the program from a terminal and read the error**.

### Installer

| Problem | Fix |
| --- | --- |
| `Could not find OozeShell.zip` | Put `OozeShell.zip` in `~/dotfiles` and run the installer again. |
| `Dotfiles directory not found` | The repository must be in `~/dotfiles` exactly (see [Step 3](#step-3-download-the-dotfiles-into-dotfiles)). |
| Refuses to run | Run it as your normal user, not root and not with `sudo`. |
| `Permission denied` | `chmod +x install-oozenix.sh` |
| It asks about an existing file | Answer `y` to back it up and link the dotfiles version, or `n` to keep yours. |
| Arch packages not installed | The installer lists them at the end. Check names with `pacman -Ss <name>` or `paru -Ss <name>`. `matugen`, `mpvpaper`, `awww` and some fonts can live in the AUR and need `paru` or `yay`. |
| Warning that `hyprland` is older than 0.55 | Update Hyprland. `hyprland.lua` needs 0.55 or newer. |
| `nix-rofi` or `git-update` not found | `nix-rofi` is linked only on non-Arch; `git-update` never automatically. Check that `echo $PATH` includes `~/.local/bin`. |

### OozeShell

| Problem | Fix |
| --- | --- |
| Nothing appears after logging in | Open a terminal (press `SUPER+I` for the keybinds, or check `hypr/modules/input/keybinds.lua`) and run `quickshell -c OozeShell`. Read the errors it prints. |
| Does not start | `which quickshell`, then `quickshell -c OozeShell` and read the errors. Run `bash Tools/check.sh` from the OozeShell folder. |
| Bar or wallpaper does not show on my screen | The default target monitor is named `DP-3`. Press `SUPER+L` to pick yours, or run `oozeshell monitor set auto`. List your monitor names with `hyprctl monitors`. |
| Icons are empty squares | Install JetBrainsMono Nerd Font and Symbols Nerd Font Mono. Arch installs the fontconfig fallback for you; on NixOS see `Tools/fonts/fonts.nix.example`. |
| Emoji show as empty boxes | Install a color emoji font (`noto-fonts-emoji` on Arch). |
| Package search does nothing | NixOS: `which nix-search`. Arch: check that `pacman` and `paru`/`yay` work. The rest of the shell is unaffected. |
| No wallpapers listed | `mkdir -p ~/Pictures/Wallpapers` and put images in it, or change the folder in **Settings → Wallpapers**. |
| Screen recording does nothing | Check `which wf-recorder`. On Arch run `sudo pacman -S wf-recorder` (the installer does this). The command and its errors are logged in `~/.cache/oozeshell/rec.log`. |
| Screenshots or recordings land in the home folder | Run `xdg-user-dirs-update` once, or set the folders in **Advanced Settings → Captures & recording**. |
| Hyprland ignores appearance changes | `hyprctl reload`. It is a Hyprland reload timing issue. |
| Native core build fails with `CMakeCache.txt ... different` | Delete the stale build folder: `rm -rf ~/dotfiles/.config/quickshell/OozeShell/native/AnimationController/build`, then build again. The installer already does this. |
| Native core rejected by Qt (NixOS) | The Qt in `native/shell.nix` must be the same one `quickshell` uses. |
| Vesktop theme does not appear | The link must point to `~/.config/vesktop/themes`. Run the installer again. |

### Waybar and Matugen

| Problem | Fix |
| --- | --- |
| Waybar option is disabled in Settings | Install `waybar`. |
| Colors do not change after a wallpaper change | Read `$XDG_RUNTIME_DIR/waybar-ctl/reload.log`. "SIGUSR2 sent" means the signal went out; "no pidfile" means Waybar was not started by OozeShell. Also check that `matugen/scripts/reload-waybar.sh` is executable. |
| A Waybar stays after switching to the OozeShell bar | `pkill -x waybar`, then switch again. Waybar must only be started through `waybar-launcher.sh`, never by hand or by other scripts. |
| Static theme keeps being overwritten | Disable `[templates.waybar]` in `~/.config/matugen/config.toml`. |
| Notification icon in Waybar stays empty | `waybar/scripts/notify-state.sh` needs OozeShell running. |

---

## Repository layout

```text
dotfiles/
├── .config/
│   ├── alacritty/  cava/  dolphin/  fastfetch/  foot/  ghostty/  kitty/  nvim/  wezterm/  yazi/
│   ├── hypr/             hyprland.lua + modules/ (appearance, hardware, input, rules, startup, system)
│   ├── matugen/          config.toml, templates/, scripts/reload-waybar.sh
│   ├── niri/  mango/     other compositors
│   ├── quickshell/OozeShell/    extracted by the installer
│   ├── waybar/           configs, waybar-launcher.sh, scripts/, themes/
│   ├── rofi/  swaync/  swayosd/
│   ├── VK-Th/themes/     Vesktop theme
│   └── starship.toml
├── install-oozenix.sh
├── update-oozenix.sh     updater for an existing install
├── INSTALLER.md          block-by-block explanation of the installer
├── OozeShell.zip         single build for every system and compositor
├── OozeWalls/            optional Rust live-wallpaper engine
├── git-update  nix-rofi  random-fastfetch  .zshrc
├── NixOSInstallation.md  dependency list for NixOS (generated on non-Arch installs)
├── SuwayomiSetup.md      generated when Suwayomi is skipped on Arch
└── screenshots/  README.md
```

OozeShell internals (each module has its own architecture note in `OozeShell/Docs/Architecture/`):

```text
OozeShell/
├── shell.qml                 entry point, popups, IPC handlers
├── Modules/                  Bar, Pill, Dock, Dashboard, Menu, Overview, Lock, Power,
│                             Taskbar, Tray, Widgets, Keybinds, SystemMonitor, Privacy
├── Services/                 Audio, OozeAudio, Bluetooth, Network, Battery, Brightness,
│                             Clipboard, Notify, Agenda, Mpris, Launcher, PackageSearch,
│                             Walls, Screenshot, Monitor, DefaultApps, Caps, Lang, Caffeine,
│                             Agents
├── Settings/                 settings pages and registry
├── Core/                     config, state and IPC targets
├── Backends/                 native/ and python/ (ooze-daemon.py)
├── COMMON/                   shared widgets and state
├── Assets/                   fonts and logos
├── Docs/                     architecture notes
├── native/                   optional C++ core
└── Tools/                    check.sh, build-native.sh, ooze-run.sh, capture and wallpaper scripts, fonts
```

---

## Screenshots

| Desktop | Launcher | Terminal |
| --- | --- | --- |
| ![Desktop](screenshots/Desktop.png) | ![Launcher](screenshots/Launcher.png) | ![Ghostty](screenshots/Terminal.png) |

| Bar | Wallpaper selector |
| --- | --- |
| ![Bar](screenshots/Bar.png) | ![Wallpaper selector](screenshots/WallpaperChanger.png) |

| Waybar | wlogout |
| --- | --- |
| ![Waybar](screenshots/waybar.png) | ![wlogout](screenshots/wlogout.png) |

---

## NixOS system configuration

System-level configuration (packages, NVIDIA drivers, services, Hyprland integration) lives in [nix-home](https://github.com/shizukutakahashi55-del/nix-home). This repository covers user-level dotfiles only.

## License

Personal configuration files. Use, modify and adapt them as you wish.
