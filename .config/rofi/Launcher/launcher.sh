#!/usr/bin/env bash

dir="$HOME/.config/rofi/Launcher"
theme='MainStyle'

WALL=$(awww query | grep -oP '(?<=image: ).*' | head -n1)
[ -z "$WALL" ] && WALL="$HOME/.config/rofi/fallback.jpg"

DUMMY_W=540
DUMMY_H=460
CACHE_IMG="/tmp/rofi_wall_preview.png"
LAST_WALL_FILE="/tmp/rofi_wall_last.txt"

# Solo reprocesa si el wallpaper cambió desde la última vez
if [ ! -f "$CACHE_IMG" ] || [ "$(cat "$LAST_WALL_FILE" 2>/dev/null)" != "$WALL" ]; then
    magick "$WALL" -resize "${DUMMY_W}x${DUMMY_H}^" -gravity center \
        -extent "${DUMMY_W}x${DUMMY_H}" "$CACHE_IMG"
    echo "$WALL" > "$LAST_WALL_FILE"
fi

rofi \
    -show drun \
    -theme "${dir}/${theme}.rasi" \
    -theme-str "dummy { background-image: url(\"${CACHE_IMG}\", none); }"
