# NixOS Dotfiles

Personal dotfiles for a **NixOS + Hyprland + NVIDIA** Wayland desktop, focused on customization, dynamic theming, desktop utilities, and a highly integrated **OozeShell** experience.

These dotfiles are centered around **OozeShell**, a custom QuickShell-based desktop shell that replaces or integrates several traditional desktop components such as the bar, launcher, notification interface, wallpaper selector, media controls, system controls, and more.

> **⚠️ Highly recommended:** Use these dotfiles together with **Nix Home / NixOS configuration** to ensure all required packages, services, fonts, and system dependencies are available.
>
> If you are not using the accompanying NixOS configuration, read the entire README and install the required dependencies manually.

> **⚠️ Important:** This repository contains user-level configuration from my personal system. It is provided as a starting point and may require adjustments for different hardware, usernames, paths, monitors, GPUs, installed packages, and desktop environments.

---

## 📋 Requirements

### Base

* **NixOS**
* **Wayland**
* **Hyprland**
* **NVIDIA GPU** recommended for the current configuration
* **JetBrainsMono Nerd Font**
* A supported terminal emulator:

  * Foot
  * Kitty
  * Alacritty
  * WezTerm
  * Ghostty

System-level packages, drivers, services, and NixOS configuration are maintained separately in:

* [nix-home](https://github.com/shizukutakahashi55-del/nix-home)

This repository is primarily responsible for **user-level configuration**.

---

## 🖥️ OozeShell Requirements

OozeShell is the main component of these dotfiles and is built with **QuickShell / Qt6**.

### QuickShell

* **QuickShell** / `quickshell-git`
* QuickShell wrapper/helper used by the configuration

### Qt6 modules

OozeShell requires Qt6 with the following components:

* `QtQuick`
* `QtQuick.Controls`
* `QtQuick.Layouts`
* `QtQuick.Shapes`
* `QtQuick.Effects`
* `QtQml`

### System utilities used by OozeShell

| Dependency         | Purpose                            |
| ------------------ | ---------------------------------- |
| `wpctl`            | WirePlumber / audio control        |
| `brightnessctl`    | Brightness control                 |
| `powerprofilesctl` | Power profile control              |
| `nmcli`            | NetworkManager / Wi-Fi connections |
| `playerctl`        | Media player / MPRIS control       |
| `bluetoothd`       | Bluetooth through BlueZ / D-Bus    |
| `matugen`          | Dynamic wallpaper-based theming    |
| `mpvpaper`         | Wallpaper/video playback           |
| `mpv`              | Backend for mpvpaper               |
| `ffmpeg`           | Media processing                   |
| `socat`            | IPC / communication utilities      |
| `wl-copy`          | Wayland clipboard support          |
| `pgrep`            | Process detection                  |

### NixSearch

The Nix package search functionality is **optional**.

If you want to use the Nix package search integration:

* `nix-search` / `nix-search-cli`
* `nix`

`wl-copy` is also used by the NixSearch interface for copying results.

If NixSearch is not installed, the rest of OozeShell remains functional.

---

## 📦 Included

| Component         | Purpose                               |
| ----------------- | ------------------------------------- |
| **Hyprland**      | Wayland compositor                    |
| **OozeShell**     | Main QuickShell-based desktop shell   |
| **QuickShell**    | Framework used by OozeShell           |
| **Rofi**          | Launcher / utility fallback           |
| **Waybar**        | Alternative bar configuration         |
| **SwayNC**        | Notification daemon configuration     |
| **SwayOSD**       | Volume / brightness OSD configuration |
| **Kitty**         | Terminal configuration                |
| **WezTerm**       | Terminal configuration                |
| **Ghostty**       | Terminal configuration                |
| **Foot**          | Terminal configuration                |
| **Alacritty**     | Terminal configuration                |
| **Yazi**          | Terminal file manager                 |
| **Neovim**        | Editor configuration                  |
| **Cava**          | Audio visualizer                      |
| **Fastfetch**     | System information                    |
| **Matugen**       | Dynamic color generation              |
| **Starship**      | Shell prompt                          |
| **Zsh**           | Shell configuration                   |
| **nix-rofi**      | Nix package search utility            |
| **git-update**    | Git commit/push helper                |
| **Vesktop theme** | Custom Vesktop theme configuration    |

---

# 🌸 OozeShell

**OozeShell** is the main focus of this repository.

It is a custom **QuickShell** desktop environment layer designed around Hyprland and integrates several desktop functions into a single shell.

Current functionality includes:

* Desktop bar
* Application launcher
* Notification center
* Wallpaper selector
* Media / MPRIS controls
* Power controls
* Bluetooth controls
* Brightness controls
* Network controls
* Taskbar
* Monitor selector
* Appearance controls
* Nix package search
* Logout / power menu
* Dynamic Matugen theming
* Keyboard shortcut cheatsheet
* Vim shortcuts tab
* Language selector
* Various system widgets and controls

### Default keybind integrations

Some functionality is exposed through Hyprland keybinds, including:

| Keybind     | Function            |
| ----------- | ------------------- |
| `SUPER + I` | Keybinds cheatsheet |
| `SUPER + L` | Monitor picker      |
| `SUPER + G` | Language picker     |
| `SUPER + U` | Nix package search  |

The exact keybindings may change as OozeShell develops.

### Language picker

The current language selector includes:

* English
* Español
* Bahasa Indonesia
* 日本語

---

# 🚀 Installation

## 1. Clone the repository

Clone the repository into your home directory:

```bash
# SSH
git clone git@github.com:shizukutakahashi55-del/dotfiles.git ~/dotfiles

# HTTPS
git clone https://github.com/shizukutakahashi55-del/dotfiles.git ~/dotfiles

cd ~/dotfiles
```

---

## 2. Review the configuration

Before installing, review the configuration for your system.

At minimum, check:

* Username and paths
* GPU / NVIDIA configuration
* Monitor configuration
* Keyboard layout
* Input settings
* Wallpaper directory
* Startup applications
* Hyprland keybindings
* Terminal configuration
* Fonts
* Matugen configuration
* OozeShell paths
* Installed applications

Most paths use `$HOME` or `~`, so the configuration should not require replacing a hardcoded username.

---

## 3. Run the installer

Make the installer executable:

```bash
chmod +x setup-permissions.sh
```

Then run:

```bash
./setup-permissions.sh
```

The installer:

* Creates `~/.config`
* Creates `~/.local/bin`
* Creates symbolic links for configuration directories
* Links `.zshrc`
* Links `nix-rofi`
* Links the Vesktop theme directory
* Applies executable permissions to required scripts

---

## 🔗 Symlinks created by the installer

The installer currently manages the following configuration paths:

```text
~/.config/alacritty
~/.config/cava
~/.config/fastfetch
~/.config/foot
~/.config/ghostty
~/.config/hypr
~/.config/kitty
~/.config/matugen
~/.config/nvim
~/.config/quickshell
~/.config/rofi
~/.config/swaync
~/.config/swayosd
~/.config/waybar
~/.config/wezterm
~/.config/yazi

~/.config/starship.toml

~/.config/Vesktop/Themes

~/.zshrc

~/.local/bin/nix-rofi
```

For example:

```text
~/.config/hypr
    -> ~/dotfiles/.config/hypr

~/.config/quickshell
    -> ~/dotfiles/.config/quickshell

~/.config/matugen
    -> ~/dotfiles/.config/matugen

~/.local/bin/nix-rofi
    -> ~/dotfiles/nix-rofi
```

Because these are symbolic links, editing:

```text
~/.config/hypr/
```

actually modifies:

```text
~/dotfiles/.config/hypr/
```

There is no separate synchronization step.

---

## ⚠️ Installer behavior

The installer is designed to avoid overwriting existing configuration.

If a target already exists as a **real file or directory**, it is skipped.

If a target is already a symbolic link pointing to the correct dotfiles location, it is left unchanged.

If a target is an existing symbolic link pointing somewhere else, the installer replaces that symbolic link.

> **⚠️ Back up your configuration before installing if you want a clean setup.**

For example:

```bash
mv ~/.config/hypr ~/.config/hypr.backup
```

Then run the installer again.

---

## 🧩 `git-update`

`git-update` is included in the repository but is **not currently linked automatically by `setup-permissions.sh`**.

You can run it directly:

```bash
~/dotfiles/git-update
```

Or manually install the symlink:

```bash
ln -s ~/dotfiles/git-update ~/.local/bin/git-update
chmod +x ~/dotfiles/git-update
```

---

## 🛠️ Utilities

### `nix-rofi`

`nix-rofi` is a Rofi-based Nix package search utility.

It is installed through:

```text
~/.local/bin/nix-rofi
```

Run it with:

```bash
nix-rofi
```

The NixSearch integration is also available from OozeShell.

It depends on the Nix search CLI being installed.

If `nix-search` is unavailable, only the NixSearch functionality is affected.

---

# 🎨 Dynamic Theming

This configuration uses **Matugen** to generate colors dynamically from the current wallpaper.

Matugen can generate themes for several applications, including:

* Hyprland
* Waybar
* Rofi
* SwayNC
* SwayOSD
* Cava
* Starship
* Yazi
* Kitty
* Other OozeShell components

Templates are located in:

```text
~/.config/matugen/templates/
```

and the main configuration is:

```text
~/.config/matugen/config.toml
```

---

# 🎨 Waybar

Waybar is included as an alternative to OozeShell.

It can be styled in two ways.

### Matugen

Matugen dynamically generates:

```text
~/.config/waybar/style.css
```

using:

```toml
[templates.waybar]

input_path  = "~/.config/matugen/templates/waybar.css"
output_path = "~/.config/waybar/style.css"

post_hook   = "pkill waybar; sleep 0.3; waybar &>/dev/null &"
```

### Static themes

Static themes are available in:

```text
.config/waybar/themes/
```

List them with:

```bash
ls ~/dotfiles/.config/waybar/themes
```

The included theme switcher can be used with:

```bash
./.config/waybar/themes/waybar-theme-switcher.sh
```

### ⚠️ Matugen vs static themes

These two methods are mutually exclusive because both can write to:

```text
~/.config/waybar/style.css
```

If you want to use a static Waybar theme, disable the `[templates.waybar]` section in Matugen and restart Waybar.

---

# 🖼️ Wallpapers

OozeShell expects wallpapers to be stored in:

```text
~/Pictures/Wallpapers
```

Create the directory with:

```bash
mkdir -p ~/Pictures/Wallpapers
```

The wallpaper selector reads from this directory by default.

If you use another location, update:

```text
.config/hypr/OozeShell/WALLS/Walls.qml
```

---

# 🔍 User-Specific Paths

The configuration generally uses:

```text
~
$HOME
```

instead of hardcoded usernames or absolute paths.

You can search for references to the original username with:

```bash
grep -RIn --exclude-dir=.git 'oozenix' ~/dotfiles
```

The username may appear in cosmetic installer output and does not normally affect functionality.

Still review the following manually:

* GPU configuration
* Monitor configuration
* Keyboard layout
* Wallpaper location
* Startup applications
* Hyprland keybindings
* Terminal choice
* File manager
* Launcher
* Installed applications

---

# 📁 Repository Structure

```text
dotfiles/
├── .config/
│   ├── alacritty/
│   ├── cava/
│   ├── fastfetch/
│   ├── foot/
│   ├── ghostty/
│   ├── hypr/
│   │   ├── hyprland.lua
│   │   └── modules/
│   │       ├── appearance/
│   │       ├── hardware/
│   │       ├── input/
│   │       ├── rules/
│   │       ├── startup/
│   │       └── system/
│   ├── kitty/
│   ├── matugen/
│   ├── nvim/
│   ├── quickshell/
│   │   └── OozeShell/
│   ├── rofi/
│   ├── swaync/
│   ├── swayosd/
│   ├── VK-Th/
│   ├── waybar/
│   │   └── themes/
│   │       ├── catppuccin-mocha.css
│   │       ├── ...
│   │       └── waybar-theme-switcher.sh
│   ├── wezterm/
│   └── yazi/
│
├── .zshrc
├── git-update
├── nix-rofi
├── README.md
├── screenshots/
└── setup-permissions.sh
```

---

# 🖼️ Screenshots

| Desktop                             | Launcher                              | Ghostty                             |
| ----------------------------------- | ------------------------------------- | ----------------------------------- |
| ![Desktop](screenshots/Desktop.png) | ![Launcher](screenshots/Launcher.png) | ![Ghostty](screenshots/Ghostty.png) |

| Bar                         | WallpaperShell                                      | OozeLogout                                |
| --------------------------- | --------------------------------------------------- | ----------------------------------------- |
| ![Bar](screenshots/Bar.png) | ![WallpaperShell](screenshots/WallpaperChanger.png) | ![Oozelogout](screenshots/Oozelogout.png) |

---

# 🗑️ Removing the Dotfiles

The configuration is installed using symbolic links, so removing a link does **not** remove the repository.

Before removing anything, verify the target:

```bash
readlink -f ~/.config/hypr
```

Expected result:

```text
/home/<your-user>/dotfiles/.config/hypr
```

You can then remove the links:

```bash
rm ~/.config/alacritty \
   ~/.config/cava \
   ~/.config/fastfetch \
   ~/.config/foot \
   ~/.config/ghostty \
   ~/.config/hypr \
   ~/.config/kitty \
   ~/.config/matugen \
   ~/.config/nvim \
   ~/.config/quickshell \
   ~/.config/rofi \
   ~/.config/swaync \
   ~/.config/swayosd \
   ~/.config/waybar \
   ~/.config/wezterm \
   ~/.config/yazi \
   ~/.config/starship.toml \
   ~/.config/Vesktop/Themes \
   ~/.zshrc
```

And:

```bash
rm ~/.local/bin/nix-rofi
```

> **⚠️ Only remove paths that are actually symlinks to this repository.**

---

# ⚠️ Troubleshooting

### Existing configuration blocks installation

The installer skips existing real files and directories instead of overwriting them.

Back up the existing configuration:

```bash
mv ~/.config/hypr ~/.config/hypr.backup
```

Then run:

```bash
./setup-permissions.sh
```

---

### Permission denied when running the installer

Run:

```bash
chmod +x setup-permissions.sh
./setup-permissions.sh
```

---

### `nix-rofi` not found

Check that the symlink exists:

```bash
ls -l ~/.local/bin/nix-rofi
```

Then check:

```bash
echo $PATH
```

If necessary:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add the same line to `.zshrc` if you want it permanently.

---

### `git-update` does not work

`git-update` is not currently installed automatically by the installer.

Install it manually:

```bash
ln -s ~/dotfiles/git-update ~/.local/bin/git-update
chmod +x ~/dotfiles/git-update
```

Then verify:

```bash
which git-update
```

---

### NixSearch keybind does nothing

The NixSearch integration requires the Nix search CLI.

Check:

```bash
which nix-search
```

If it is not installed, install the required package or disable the NixSearch functionality.

This does not affect the rest of OozeShell.

---

### OozeShell does not start

First verify that QuickShell is available:

```bash
which quickshell
```

Then verify the required dependencies listed in the **OozeShell Requirements** section.

You can also test the shell directly:

```bash
quickshell -p ~/.config/quickshell/OozeShell/shell.qml
```

---

### Wallpaper selector does not find wallpapers

Verify that the wallpaper directory exists:

```bash
ls ~/Pictures/Wallpapers
```

Create it if necessary:

```bash
mkdir -p ~/Pictures/Wallpapers
```

If you use another location, update the path in:

```text
.config/hypr/OozeShell/WALLS/Walls.qml
```

---

### Static Waybar theme keeps getting overwritten

Matugen is probably still generating:

```text
~/.config/waybar/style.css
```

Disable the `[templates.waybar]` section in:

```text
~/.config/matugen/config.toml
```

Then restart Waybar.

---

# 🖥️ NixOS Configuration

System-level configuration is maintained separately in:

* [nix-home](https://github.com/shizukutakahashi55-del/nix-home)

That repository handles things such as:

* NixOS system configuration
* Packages
* NVIDIA drivers
* Hardware configuration
* Services
* Hyprland system integration
* System-level dependencies

This repository focuses on **user-level dotfiles and desktop customization**.

---

# 📜 License

Personal configuration files.

Use, modify, and adapt them as you wish.
