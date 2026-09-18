
#!/usr/bin/env bash

dir="$HOME/.config/rofi/Launcher"
theme="MainStyle"

# ─────────────────────────────────────────────────────────────
# Wallpaper
# ─────────────────────────────────────────────────────────────

WALL="$HOME/Pictures/Wallpapers/current.jpg"

if [ ! -f "$WALL" ]; then
    WALL="$HOME/.config/rofi/fallback.jpg"
fi

# ─────────────────────────────────────────────────────────────
# Preview
# ─────────────────────────────────────────────────────────────

DUMMY_W=540
DUMMY_H=460

CACHE_IMG="/tmp/rofi_wall_preview.png"
LAST_WALL_FILE="/tmp/rofi_wall_last.txt"

if [ ! -f "$CACHE_IMG" ] || \
   [ "$(cat "$LAST_WALL_FILE" 2>/dev/null)" != "$WALL" ]; then

    if [ -f "$WALL" ]; then
        magick "$WALL" \
            -resize "${DUMMY_W}x${DUMMY_H}^" \
            -gravity center \
            -extent "${DUMMY_W}x${DUMMY_H}" \
            "$CACHE_IMG"

        echo "$WALL" > "$LAST_WALL_FILE"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Rofi — KDE
# No usamos el modo "window" porque KWin no expone
# wlr-foreign-toplevel-management.
# ─────────────────────────────────────────────────────────────

exec rofi \
    -show drun \
    -modi "drun,run,filebrowser" \
    -theme "${dir}/${theme}.rasi" \
    -theme-str "dummy { background-image: url(\"${CACHE_IMG}\", none); }"
