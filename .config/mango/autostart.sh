#!/usr/bin/env bash

# Se ejecuta al iniciar Mango (exec-once en config.conf)
# ~ startup/autostart.lua
# ─────────────────────────────────────────────
# Entorno para systemd / dbus (portales, screen share)
# ─────────────────────────────────────────────
dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY DISPLAY \
    XDG_CURRENT_DESKTOP=mango \
    XDG_SESSION_TYPE=wayland \
    NIXOS_OZONE_WL XCURSOR_THEME XCURSOR_SIZE

systemctl --user import-environment \
    WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

# Por si algún portal ya arrancó con el entorno vacío
systemctl --user try-restart xdg-desktop-portal-wlr xdg-desktop-portal 2>/dev/null

# ─────────────────────────────────────────────
# Terminal
# ─────────────────────────────────────────────

# Terminal al iniciar (tras 3s, igual que programs.start_terminal(3))
( sleep 3 && setsid -f foot ) &

# ─────────────────────────────────────────────
# Daemons
# ─────────────────────────────────────────────

nm-applet &

awww-daemon &

systemctl --user start hyprpolkitagent 2>/dev/null || {
    command -v polkit-gnome-authentication-agent-1 >/dev/null &&
        polkit-gnome-authentication-agent-1 &
}

# ─────────────────────────────────────────────
# OozeShell-mango
# ─────────────────────────────────────────────

# Evitar instancias duplicadas de Quickshell
pkill -x quickshell 2>/dev/null
sleep 1

quickshell -p ~/.config/quickshell/OozeShell/shell.qml &

# ─────────────────────────────────────────────
# Idle / bloqueo
# ─────────────────────────────────────────────

hypridle -c ~/.config/mango/hypridle.conf &

# ─────────────────────────────────────────────
# Input Method
# ─────────────────────────────────────────────

# fcitx5 -d &