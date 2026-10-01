#!/usr/bin/env bash
# Se ejecuta al iniciar Mango (exec-once en config.conf)  ~ startup/autostart.lua

# Entorno de sesion para portales / systemd --user
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=mango MANGO_INSTANCE_SIGNATURE 2>/dev/null
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP MANGO_INSTANCE_SIGNATURE 2>/dev/null

# Terminal al iniciar (tras 3s, igual que programs.start_terminal(3))
( sleep 3 && setsid -f foot ) &

# Daemons
nm-applet &
awww-daemon &
systemctl --user start hyprpolkitagent 2>/dev/null || \
  { command -v polkit-gnome-authentication-agent-1 >/dev/null && polkit-gnome-authentication-agent-1 & }

# Shell (OozeShell-mango) -- necesita mmsg y MANGO_INSTANCE_SIGNATURE
pkill quickshell; sleep 1
quickshell -p ~/.config/quickshell/OozeShell-mango/shell.qml &

# Idle / bloqueo
hypridle -c ~/.config/mango/hypridle.conf &

# fcitx5 -d &   # si usas input method
