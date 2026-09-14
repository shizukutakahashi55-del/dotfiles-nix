# NixOS Dotfiles

Personal dotfiles for a **NixOS + Hyprland** desktop environment, focused on customization, theming, terminal tools, and desktop utilities. Could work on Arch. Probably.

These dotfiles are managed with **GNU Stow**, making it easy to clone the repository, create symlinks, and keep the configuration synchronized across machines.

> **⚠️ Important:** These configurations were originally created for my personal system. They may require adjustments depending on your hardware, installed packages, usernames, paths, and system configuration.

---

## 📦 Included

The repository currently contains configuration for:

* **Hyprland** — Wayland compositor
* **Waybar** — Status bar
* **Rofi** — Application launcher
* **SwayNC** — Notification daemon
* **Kitty** — Terminal emulator
* **Cava** — Audio visualizer
* **Fastfetch** — System information
* **Matugen** — Dynamic color generation
* **Starship** — Shell prompt
* **Zsh** — Shell configuration
* **Wlogout** — Logout/power menu
* **WallpaperShell** — Wallpaper management

---

## 📁 Repository Structure

```text
dotfiles-nix/
├── .config/
│   ├── cava/
│   ├── fastfetch/
│   ├── hypr/
│   ├── kitty/
│   ├── matugen/
│   ├── rofi/
│   ├── swaync/
│   ├── waybar/
│   └── ...
│
├── .zshrc
│
├── screenshots/
│   ├── Desktop.png
│   ├── Rofi.png
│   ├── Kitty.png
│   ├── waybar.png
│   ├── WallpaperChanger.png
│   └── wlogout.png
│
└── README.md
```

---

## 🖼️ Screenshots

### Desktop

![Desktop](screenshots/Desktop.png)

### Rofi

![Rofi](screenshots/Rofi.png)

### Kitty

![Kitty](screenshots/Kitty.png)

### Waybar

![Waybar](screenshots/waybar.png)

### WallpaperShell

![WallpaperShell](screenshots/WallpaperChanger.png)

### Wlogout

![Wlogout](screenshots/wlogout.png)

---

# 🚀 Installation

## 1. Clone the repository

Clone the repository into your home directory:

```bash
git clone git@github.com:shizukutakahashi55-del/dotfiles-nix.git ~/dotfiles
```

Then enter the repository:

```bash
cd ~/dotfiles
```

If you do not have SSH configured for GitHub, you can also clone using HTTPS:

```bash
git clone https://github.com/shizukutakahashi55-del/dotfiles-nix.git ~/dotfiles
```

---

## 2. Install GNU Stow

GNU Stow is used to create symbolic links from the repository to your home directory.

On NixOS, you can temporarily install it with:

```bash
nix-shell -p stow
```

Or add it permanently to your NixOS configuration.

For example:

```nix
environment.systemPackages = with pkgs; [
  stow
];
```

After adding it to your configuration, rebuild your system:

```bash
sudo nixos-rebuild switch
```

---

## 3. Back up existing configurations

Before creating the symlinks, check whether you already have configurations for the programs included in this repository.

For example:

```bash
ls ~/.config/hypr
ls ~/.config/waybar
ls ~/.config/kitty
```

If you already have configurations that you want to keep, back them up first.

For example:

```bash
mv ~/.config/hypr ~/.config/hypr.backup
```

You can do the same for other directories:

```bash
mv ~/.config/waybar ~/.config/waybar.backup
mv ~/.config/kitty ~/.config/kitty.backup
mv ~/.config/rofi ~/.config/rofi.backup
```

> **Do not delete your existing configuration unless you are sure you no longer need it.**

---

## 4. Create the symlinks with Stow

From inside the repository:

```bash
cd ~/dotfiles
stow .
```

GNU Stow will create symbolic links in your home directory.

For example:

```text
~/.config/hypr     -> ~/dotfiles/.config/hypr
~/.config/waybar   -> ~/dotfiles/.config/waybar
~/.config/kitty    -> ~/dotfiles/.config/kitty
~/.config/rofi     -> ~/dotfiles/.config/rofi
~/.config/cava     -> ~/dotfiles/.config/cava
~/.config/swaync   -> ~/dotfiles/.config/swaync
~/.config/matugen  -> ~/dotfiles/.config/matugen
~/.config/fastfetch -> ~/dotfiles/.config/fastfetch
~/.zshrc           -> ~/dotfiles/.zshrc
```

You can verify the links with:

```bash
ls -l ~/.config/
```

Or check an individual configuration:

```bash
ls -l ~/.config/hypr
```

---

# ⚙️ After Installation

The dotfiles may require additional software that is **not included in this repository**.

Make sure the required programs are installed before starting Hyprland.

At minimum, you should review the configurations for dependencies such as:

* Hyprland
* Waybar
* Rofi
* SwayNC
* Kitty
* Cava
* Fastfetch
* Matugen
* Starship
* Zsh
* Wlogout
* Wallpaper utilities
* Fonts
* Any scripts referenced by the configuration

You should also check the configuration files for commands that may be specific to my system.

For example:

```bash
grep -R "rinooze\|oozenix\|/home/" ~/.config/hypr ~/.config/waybar
```

Replace any paths, usernames, or commands that do not exist on your system.

---

# 🎨 Waybar Themes

The Waybar configuration includes additional themes/scripts that can be used instead of the default setup.

Check the Waybar directory:

```bash
cd ~/dotfiles/.config/waybar
ls
```

If you prefer a different appearance, look through the available themes and scripts and select the one you want to use.

---

# 🖼️ Wallpapers

Some parts of the configuration expect wallpapers to be available in:

```bash
$HOME/Pictures/Wallpapers
```

Create the directory if it does not exist:

```bash
mkdir -p ~/Pictures/Wallpapers
```

Then place your wallpapers inside it.

> **Important:** If your wallp
