#!/usr/bin/env bash

# List of scripts requiring execution permissions
scripts=(
    "./.config/rofi/launcher.sh"
    "./.config/rofi/powermenu.sh"
    "./.config/rofi/bluetooth.sh"
    "./.config/waybar/themes/waybar-theme-switcher.sh"
)

echo "Granting execution permissions to scripts..."

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "  [✓] Permission granted: $script"
    else
        echo "  [✗] File not found: $script"
    fi
done

echo "Done!"

