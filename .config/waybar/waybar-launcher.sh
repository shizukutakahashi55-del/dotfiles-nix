#!/usr/bin/env bash
set -u

dir="$HOME/.config/waybar"
rt="${XDG_RUNTIME_DIR:-/tmp}/waybar-ctl"
pidfile="$rt/waybar.pid"
supfile="$rt/supervisor.pid"

mkdir -p "$rt"

select_config() {
    local cfg
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        cfg="$dir/config.jsonc"
    elif [ -n "${NIRI_SOCKET:-}" ]; then
        cfg="$dir/config-niri.jsonc"
    elif [ -n "${MANGO_SOCKET:-}" ] || pgrep -x mango >/dev/null 2>&1; then
        cfg="$dir/config-mango.jsonc"
    else
        cfg="$dir/config.jsonc"
    fi
    [ -f "$cfg" ] || cfg="$dir/config.jsonc"
    printf '%s' "$cfg"
}

is_alive() {
    [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null
}

is_waybar() {
    tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q 'waybar'
}

is_launcher() {
    tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q 'waybar-launcher\.sh'
}

kill_pid() {
    local pid="$1" i
    kill -TERM "$pid" 2>/dev/null || return 0
    for i in $(seq 1 30); do
        is_alive "$pid" || return 0
        sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null
    for i in $(seq 1 10); do
        is_alive "$pid" || return 0
        sleep 0.1
    done
}

old_sup=$(cat "$supfile" 2>/dev/null || true)
if [ -n "$old_sup" ] && [ "$old_sup" != "$$" ] && is_alive "$old_sup" && is_launcher "$old_sup"; then
    kill_pid "$old_sup"
fi

old_bar=$(cat "$pidfile" 2>/dev/null || true)
if [ -n "$old_bar" ] && is_alive "$old_bar" && is_waybar "$old_bar"; then
    kill_pid "$old_bar"
fi

rm -f "$pidfile"
printf '%s' "$$" > "$supfile"

child=0
stopping=0

shutdown() {
    stopping=1
    if [ "$child" -gt 0 ] && is_alive "$child"; then
        kill_pid "$child"
    fi
    rm -f "$pidfile" "$supfile"
    exit 0
}

trap shutdown TERM INT HUP

fails=0

while [ "$stopping" -eq 0 ]; do
    cfg=$(select_config)
    started=$(date +%s)

    waybar -c "$cfg" -s "$dir/style.css" &
    child=$!
    printf '%s' "$child" > "$pidfile"

    wait "$child"

    rm -f "$pidfile"
    child=0

    [ "$stopping" -eq 0 ] || break

    if [ $(( $(date +%s) - started )) -lt 3 ]; then
        fails=$(( fails + 1 ))
    else
        fails=0
    fi

    if [ "$fails" -ge 5 ]; then
        rm -f "$supfile"
        exit 1
    fi

    sleep 0.5
done

rm -f "$supfile"
