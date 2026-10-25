#!/usr/bin/env bash
# Reinicia OozeShell de forma limpia: cierra la instancia actual y arranca una nueva.
#
# Por qué no basta con "quickshell kill" (Quickshell 0.3.0):
#   Tras un crash, Quickshell se relanza a sí mismo con execve (mismo PID). Esa instancia
#   "relanzada" tiene un bug: al salir con normalidad (kill / IPC exit) hace abort() con
#   "Quickshell's log filter has been installed twice" y vuelve a relanzarse, así que el
#   proceso nunca llega a desaparecer. Por eso aquí se espera, y lo que siga vivo pasado
#   un margen se mata con SIGKILL (SIGKILL no pasa por el crash handler: no hay relanzamiento).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="${QS:-quickshell}"
PREFIX="${OOZE_PREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/qml}"

if [ -f "$PREFIX/OozeShell/Native/qmldir" ]; then
  case ":${QML_IMPORT_PATH:-}:" in
    *":$PREFIX:"*) ;;
    *) export QML_IMPORT_PATH="$PREFIX${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" ;;
  esac
fi

shell_pids() {
  local p c cmd
  for p in $(pgrep -f 'shell\.qml' 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    c=$(cat "/proc/$p/comm" 2>/dev/null) || continue
    case "$c" in *quickshell*|qs) ;; *) continue ;; esac
    cmd=$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null)
    case "$cmd" in *" ipc "*|*" kill "*) continue ;; esac
    echo "$p"
  done
}

stop_shell() {
  local grace="${OOZE_STOP_GRACE:-6}"   # sondeos de 0.3 s antes de usar SIGKILL (~1.8 s)
  local quiet_needed=3                  # sondeos seguidos sin procesos (~0.9 s)
  local quiet=0 tries=0 pids

  # Salida limpia por IPC. Sin SIGTERM inmediato: pisaba el apagado en curso.
  "$QS" kill -p "$ROOT/shell.qml" >/dev/null 2>&1 || true

  while [ "$quiet" -lt "$quiet_needed" ] && [ "$tries" -lt 60 ]; do
    tries=$((tries + 1))
    pids="$(shell_pids)"
    if [ -z "$pids" ]; then
      quiet=$((quiet + 1))
    else
      quiet=0
      if [ "$tries" -gt "$grace" ]; then
        kill -9 $pids 2>/dev/null || true
      fi
    fi
    sleep 0.3
  done
}

stop_shell

if [ "${OOZE_MALLOC_TUNE:-1}" = 1 ]; then
  export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
  export MALLOC_MMAP_THRESHOLD_="${MALLOC_MMAP_THRESHOLD_:-131072}"
  export MALLOC_TRIM_THRESHOLD_="${MALLOC_TRIM_THRESHOLD_:-131072}"
  export MALLOC_TOP_PAD_="${MALLOC_TOP_PAD_:-0}"
fi

# La instancia nueva debe arrancar limpia: si este script lo lanzó un hijo de una instancia
# relanzada tras crash, estas variables harían que Quickshell crea que se relanza.
unset __QUICKSHELL_CRASH_INFO_FD __QUICKSHELL_CRASH_DUMP_PID __QUICKSHELL_CRASH_DUMP_FD

exec "$QS" -p "$ROOT/shell.qml" "$@"
