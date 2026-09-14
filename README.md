# NixOS Dotfiles

Personal dotfiles for a **NixOS + Hyprland** desktop environment, focused on customization, theming, terminal tools, and desktop utilities.

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
│   │   └── themes/
│   │       ├── waybar-theme-switcher.sh
│   │       └── ...
│   └── ...
│
├── .zshrc
├── setup-permissions.sh
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

> **⚠️ Do not delete your existing configuration unless you are sure you no longer need it.**

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
~/.config/hypr      -> ~/dotfiles/.config/hypr
~/.config/waybar    -> ~/dotfiles/.config/waybar
~/.config/kitty     -> ~/dotfiles/.config/kitty
~/.config/rofi      -> ~/dotfiles/.config/rofi
~/.config/cava      -> ~/dotfiles/.config/cava
~/.config/swaync    -> ~/dotfiles/.config/swaync
~/.config/matugen   -> ~/dotfiles/.config/matugen
~/.config/fastfetch -> ~/dotfiles/.config/fastfetch
~/.zshrc            -> ~/dotfiles/.zshrc
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

# 🔐 Script Permissions

Some parts of the configuration use shell scripts, including:

* Rofi launchers
* Wlogout scripts
* Waybar theme switcher
* Other utility scripts included in the repository

The repository includes a helper script called:

```text
setup-permissions.sh
```

This script grants the required execution permissions to the shell scripts used by the dotfiles.

## 1. Grant execution permission to the setup script

After cloning the repository, run:

```bash
chmod +x setup-permissions.sh
```

You only need to do this **once**.

## 2. Run the permission setup

From the root of the repository:

```bash
./setup-permissions.sh
```

After running it, scripts such as the Rofi launcher, Wlogout scripts, and Waybar theme switcher should have the required execution permissions.

For example, the Waybar theme switcher is located at:

```text
.config/waybar/themes/waybar-theme-switcher.sh
```

It can be executed with:

```bash
./.config/waybar/themes/waybar-theme-switcher.sh
```

> **💡 Tip:** If one of the included scripts returns `Permission denied`, run `setup-permissions.sh` again before manually changing the permissions of individual files.

---

# ⚙️ After Installation

The dotfiles may require additional software that is **not included in this repository**.

Make sure the required programs are installed before starting Hyprland.

At minimum, review the configurations for dependencies such as:

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

You should also check the configuration files for commands or paths that may be specific to my system.

For example:

```bash
grep -R "rinooze\|oozenix\|/home/" ~/.config/hypr ~/.config/waybar
```

Replace any paths, usernames, or commands that do not exist on your system.

---

# 🎨 Waybar Themes

The repository includes multiple Waybar themes.

They are located in:

```text
.config/waybar/themes/
```

You can view the available themes with:

```bash
cd ~/dotfiles/.config/waybar/themes
ls
```

The included theme switcher is:

```text
.config/waybar/themes/waybar-theme-switcher.sh
```

Run it with:

```bash
./.config/waybar/themes/waybar-theme-switcher.sh
```

The script allows you to switch between the available Waybar themes without manually editing the Waybar configuration.

Feel free to modify the existing themes or add your own.

---

# 🖼️ Wallpapers

Some parts of the configuration expect wallpapers to be available in:

```text
$HOME/Pictures/Wallpapers
```

Create the directory if it does not exist:

```bash
mkdir -p ~/Pictures/Wallpapers
```

Then place your wallpapers inside it.

> **⚠️ Important:** If your wallpapers are stored somewhere else, update the corresponding paths in the configuration.

---

# 🔧 Customizing the Configuration

These dotfiles are meant to be customized.

After installing them, you may want to change:

* Wallpaper paths
* Monitor configuration
* Keybindings
* Application launchers
* Terminal settings
* Waybar modules
* Colors and themes
* Fonts
* User-specific paths
* Startup applications
* Scripts
* Hyprland rules

The main configuration directories are located under:

```text
~/.config/
```

Because these are symlinks, editing:

```text
~/.config/hypr/
```

will modify the files inside:

```text
~/dotfiles/.config/hypr/
```

This makes it easy to commit your changes back to Git.

---

# 🔄 Updating the Dotfiles

On another machine, or after changes have been pushed to the repository, pull the latest version:

```bash
cd ~/dotfiles
git pull
```

If the symlinks are already installed, the changes should be available immediately because your configuration directories point to the repository.

If the dotfiles have not been installed on the machine yet, run:

```bash
stow .
```

If the scripts are not executable after an update, run:

```bash
./setup-permissions.sh
```

---

# 🗑️ Removing the Dotfiles

If you want to remove the symlinks created by GNU Stow without deleting the repository:

```bash
cd ~/dotfiles
stow -D .
```

This removes the symlinks managed by Stow.

Your repository and its files will remain untouched.

---

# 🖥️ NixOS Configuration

The **system-level NixOS configuration is maintained separately** from these dotfiles.

This repository focuses on user-level configuration such as:

* Hyprland
* Waybar
* Kitty
* Rofi
* SwayNC
* Cava
* Fastfetch
* Matugen
* Starship
* Zsh
* Wlogout
* Theming
* Desktop utilities

System-level NixOS configuration is normally located at:

```text
/etc/nixos/
```

Your own NixOS configuration can therefore be used independently from these dotfiles.

---

# ⚠️ Troubleshooting

## Stow says that a file already exists

If you see an error similar to:

```text
WARNING! stowing ... would cause conflicts
```

or:

```text
ERROR: ... already exists
```

you probably already have a configuration in your home directory.

Check the conflicting file:

```bash
ls -la ~/.config/
```

Back it up if necessary:

```bash
mv ~/.config/<directory> ~/.config/<directory>.backup
```

Then try again:

```bash
cd ~/dotfiles
stow .
```

---

## Script returns `Permission denied`

Run the permission setup script:

```bash
cd ~/dotfiles
./setup-permissions.sh
```

If the setup script itself does not have execution permissions:

```bash
chmod +x setup-permissions.sh
```

Then run it again:

```bash
./setup-permissions.sh
```

---

## Check where a symlink points

Use:

```bash
readlink -f ~/.config/hypr
```

You should see something similar to:

```text
/home/<your-user>/dotfiles/.config/hypr
```

This confirms that the configuration is linked to the repository.

---

# 💡 Important Notes

These dotfiles were created for my personal **NixOS + Hyprland** environment.

They are provided as a starting point rather than a completely universal configuration.

Before using them:

1. **Read the configuration files.**
2. **Check paths and usernames.**
3. **Install the required dependencies.**
4. **Check your monitor configuration.**
5. **Check your wallpaper directory.**
6. **Review scripts before executing them.**
7. **Back up your existing configuration.**

Some scripts or configurations may reference applications that are not installed by default on your system.

You are encouraged to modify the configuration to fit your own system.

---

# 📜 License

Personal configuration files.

Use, modify, and adapt them as you wish.
