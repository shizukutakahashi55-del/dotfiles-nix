#!/usr/bin/env bash
# ============================================================
# waybar-theme-switcher.sh
# Cicla entre temas con cada llamada sin duplicar procesos.
# ============================================================

set -euo pipefail

THEMES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_CSS_DIR="$HOME/.config/waybar"
WAYBAR_CSS="$WAYBAR_CSS_DIR/style.css"
STATE_DIR="$HOME/.cache"
STATE_FILE="$STATE_DIR/waybar-current-theme"

# Lista de temas disponibles (deben coincidir con el nombre del archivo sin .css)
THEMES=(
    "catppuccin-mocha"
    "tokyo-night"
    "gruvbox"
    "scarlett"
    "rose-pine"
    "nord"
    "pastel-dream"
    "retro-terminal"
    "void-minimal"
    "neon-punk"
)

# Asegurar que existan los directorios necesarios
mkdir -p "$WAYBAR_CSS_DIR" "$STATE_DIR"

# ---------- funciones ----------

get_current_index() {
    if [[ -f "$STATE_FILE" ]]; then
        local current
        current=$(cat "$STATE_FILE")
        for i in "${!THEMES[@]}"; do
            if [[ "${THEMES[$i]}" == "$current" ]]; then
                echo "$i"
                return 0
            fi
        done
    fi
    echo "0"
}

apply_theme() {
    local theme="$1"
    local css_file="$THEMES_DIR/${theme}.css"

    if [[ ! -f "$css_file" ]]; then
        echo "Error: no se encontró el archivo CSS '$css_file'" >&2
        exit 1
    fi

    # Copia el CSS al destino principal de waybar
    cp "$css_file" "$WAYBAR_CSS"

    # Guarda el estado actual
    echo "$theme" > "$STATE_FILE"

    # Si waybar está corriendo, recarga el estilo en vivo sin reiniciar.
    # Si no está corriendo, lo inicia.
    if pgrep -x waybar >/dev/null; then
        pkill -SIGUSR2 waybar
    else
        waybar &>/dev/null &
    fi

    # Notificación opcional
    if command -v notify-send &>/dev/null; then
        notify-send -t 2000 -i preferences-desktop-theme \
            "Waybar Theme" "Nuevo tema: $theme"
    fi

    echo "Tema aplicado: $theme"
}

# ---------- lógica principal ----------

if [[ -n "${1:-}" ]]; then
    # Modo: tema específico por nombre
    apply_theme "$1"
else
    # Modo: ciclar al siguiente
    current_index=$(get_current_index)
    next_index=$(( (current_index + 1) % ${#THEMES[@]} ))
    apply_theme "${THEMES[$next_index]}"
fi
