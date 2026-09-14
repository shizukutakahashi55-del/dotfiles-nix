# NixOS Dotfiles

Personal dotfiles for my NixOS setup, focused on **Hyprland**, customization, theming, terminal tools, and desktop utilities.

## 📦 Included

The repository currently contains configuration for:

- **Hyprland** — Wayland compositor
- **Waybar** — Status bar
- **Rofi** — Application launcher
- **SwayNC** — Notification daemon
- **Kitty** — Terminal emulator
- **Cava** — Audio visualizer
- **Fastfetch** — System information
- **Matugen** — Dynamic color generation
- **Starship** — Shell prompt
- **Zsh** — Shell configuration

### Structure

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
│   └── starship.toml
│
└── .zshrc
```

---
## Screenshots

### Desktop

![Desktop](screenshots/Desktop.png)

### Rofi

![Rofi](screenshots/Rofi.png)

### Kitty

![Kitty](screenshots/Kitty.png)

### Waybar

![Waybar](screenshots/waybar.png)

### WallpaperShell

![WalpaperShell](screenshots/WallpaperChanger.png)

### Wlogout

![Wlogout](screenshots/wlogout.png)

## 🚀 Installation

### 1. Clone the repository

```bash
git clone git@github.com:shizukutakahashi55-del/dotfiles-nix.git ~/dotfiles
```

Enter the directory:

```bash
cd ~/dotfiles
```

### 2. Install GNU Stow

On NixOS:

```bash
nix-shell -p stow
```

Or, if you already have `stow` available:

```bash
stow .
```

### 3. Create the symlinks

From inside the repository:

```bash
stow .
```

This will create links such as:

```text
~/.config/hypr    -> ~/dotfiles/.config/hypr
~/.config/waybar  -> ~/dotfiles/.config/waybar
~/.config/kitty   -> ~/dotfiles/.config/kitty
~/.config/rofi    -> ~/dotfiles/.config/rofi
~/.config/cava    -> ~/dotfiles/.config/cava
~/.config/swaync  -> ~/dotfiles/.config/swaync
~/.config/matugen -> ~/dotfiles/.config/matugen
~/.config/fastfetch -> ~/dotfiles/.config/fastfetch
~/.zshrc          -> ~/dotfiles/.zshrc
```

---

## ⚠️ Existing configuration files

If the configuration already exists in your home directory, GNU Stow may refuse to create the symlink.

For example:

```text
~/.config/hypr
```

If it already exists and contains your current configuration, back it up before running Stow:

```bash
mv ~/.config/hypr ~/.config/hypr.backup
```

Then run:

```bash
cd ~/dotfiles
stow .
```

After verifying everything works, the backup can be removed.

---


## 🔁 Updating another machine

Pull the latest version:

```bash
cd ~/dotfiles
git pull
```

If the dotfiles have not been installed yet:

```bash
stow .
```

---

## 🗑️ Removing the symlinks

If you want to remove the dotfiles from your home directory without deleting the repository:

```bash
cd ~/dotfiles
stow -D .
```

This removes the symlinks created by Stow.

---

## 🖥️ NixOS Configuration

The NixOS system configuration is maintained separately from these user-level dotfiles.

The dotfiles repository is intended to contain:

- User configuration
- Hyprland configuration
- Waybar configuration
- Terminal configuration
- Shell configuration
- Theming
- Desktop utilities

System-level NixOS configuration remains under:

```text
/etc/nixos/
```

---

## 📝 Notes

This repository is primarily intended for my personal NixOS environment.

Some configurations may depend on additional packages, fonts, scripts, or services that are not included in this repository.

Before using these dotfiles on another system, review the configuration and install the required dependencies.

If you don't like the Waybar default, you can use a .sh on Waybar folder, I have some themes you may like. 

These are dotfiles for my main system with NixOS, remember to verify all the files and change folder names, or links.

---

## 📜 License

Personal configuration files. Use, modify, and adapt them as you wish.