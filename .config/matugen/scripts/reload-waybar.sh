#!/usr/bin/env bash
set -u

rt="${XDG_RUNTIME_DIR:-/tmp}/waybar-ctl"
pidfile="$rt/waybar.pid"
tokenfile="$rt/reload.token"
logfile="$rt/reload.log"

log() {
    printf '%s %s\n' "$(date +%H:%M:%S)" "$1" >> "$logfile"
}

if [ -z "${WAYBAR_RELOAD_DETACHED:-}" ]; then
    WAYBAR_RELOAD_DETACHED=1 setsid -f "$0" >/dev/null 2>&1 </dev/null
    exit 0
fi

mkdir -p "$rt"

token="$$-$(date +%s%N)"
printf '%s' "$token" > "$tokenfile"

sleep 0.4

[ "$(cat "$tokenfile" 2>/dev/null)" = "$token" ] || exit 0

pid=$(cat "$pidfile" 2>/dev/null || true)

if [ -z "$pid" ]; then
    log "sin pidfile: waybar no esta bajo el supervisor"
    exit 0
fi

if ! kill -0 "$pid" 2>/dev/null; then
    log "pid $pid ya no existe"
    exit 0
fi

if kill -USR2 "$pid" 2>/dev/null; then
    log "SIGUSR2 enviado a $pid"
else
    log "fallo al enviar SIGUSR2 a $pid"
fi

exit 0
