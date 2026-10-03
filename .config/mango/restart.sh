#!/usr/bin/env bash
# ~/.config/mango/scripts/restart.sh
pkill quickshell
sleep 1
exec quickshell -p ~/.config/quickshell/OozeShell/shell.qml