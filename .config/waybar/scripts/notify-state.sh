#!/usr/bin/env bash
set -u

parent="$PPID"

while kill -0 "$parent" 2>/dev/null; do
    P=$(pgrep -f 'quickshell.* (-p|-c|--path|--config)[ =].*OozeShell' | head -n 1)

    if [ -n "$P" ]; then
        st=$(quickshell ipc --pid "$P" call notify state 2>/dev/null) || st='{}'
    else
        st='{}'
    fi

    c=$(printf '%s' "$st" | jq -r '.count // 0' 2>/dev/null || echo 0)
    d=$(printf '%s' "$st" | jq -r '.dnd // false' 2>/dev/null || echo false)

    if [ "$d" = "true" ]; then
        if [ "$c" -gt 0 ]; then
            alt="dnd-notification"
            tip="No molestar — $c notificaciones"
        else
            alt="dnd-none"
            tip="No molestar"
        fi
    else
        if [ "$c" -gt 0 ]; then
            alt="notification"
            tip="$c notificaciones"
        else
            alt="none"
            tip="Sin notificaciones"
        fi
    fi

    printf '{"text":"","alt":"%s","tooltip":"%s","class":"%s"}\n' \
        "$alt" \
        "$tip" \
        "$alt"

    sleep 2
done
