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
