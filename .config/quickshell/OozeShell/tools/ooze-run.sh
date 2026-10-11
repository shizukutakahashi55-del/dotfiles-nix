# tools/ooze-run.sh — compila, ejecuta y mide OozeShell con su backend en C++.
# Opciones de `run`:

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="${QS_BIN:-quickshell}"
PREFIX="${OOZE_PREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/qml}"
LOGDIR="${OOZE_LOGDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oozeshell/bench}"
NATIVE_SO_DIR="$PREFIX/OozeShell/Native"

c_ok=$'\e[32m'; c_bad=$'\e[31m'; c_dim=$'\e[2m'; c_b=$'\e[1m'; c_0=$'\e[0m'
[ -t 1 ] || { c_ok=; c_bad=; c_dim=; c_b=; c_0=; }
say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✔%s %s\n' "$c_ok" "$c_0" "$*"; }
bad()  { printf '  %s✘%s %s\n' "$c_bad" "$c_0" "$*"; }
head_() { printf '\n%s── %s%s\n' "$c_b" "$*" "$c_0"; }

# ─────────────────────────────────────────────────────────────── utilidades
have() { command -v "$1" >/dev/null 2>&1; }

native_built() { compgen -G "$NATIVE_SO_DIR/*.so" >/dev/null 2>&1 && [ -f "$NATIVE_SO_DIR/qmldir" ]; }


shell_pids() {
  local p c cmd
  for p in $(pgrep -f quickshell 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    c=$(cat "/proc/$p/comm" 2>/dev/null) || continue
    case "$c" in *quickshell*|qs) ;; *) continue ;; esac
    cmd=$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null)
    case "$cmd" in *"$ROOT"*|*OozeShell*|*shell.qml*) echo "$p" ;; esac
  done
}

stop_shell() {
  local p; p="$(shell_pids)"
  [ -z "$p" ] && return 0

  kill $p 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do sleep 0.3; [ -z "$(shell_pids)" ] && return 0; done

  kill -9 $(shell_pids) 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────── build
cmd_build() {
  head_ "Compilando el módulo C++ (OozeShell.Native)"
  if ! have cmake; then
    if have nix-shell; then
      say "  cmake no está en el PATH: entro a nix-shell (native/shell.nix)…"
      nix-shell "$ROOT/native/shell.nix" --run "bash '$ROOT/tools/build-native.sh' '$PREFIX'"
      return $?
    fi
    bad "No encuentro cmake ni nix-shell. Instala cmake, un compilador C++17 y Qt6 (qtbase + qtdeclarative)."
    return 1
  fi
  bash "$ROOT/tools/build-native.sh" "$PREFIX"
}

# ─────────────────────────────────────────────────────────────── backends
cmd_backends() {
  head_ "Backends de OozeShell"

  say "${c_b}C++ (módulo OozeShell.Native)${c_0}"
  if native_built; then ok "compilado en $NATIVE_SO_DIR"; else bad "NO compilado  →  bash tools/ooze-run.sh build"; fi
  for src in AnimationController SystemStats FontProbe ActiveSource; do
    f="$ROOT/native/AnimationController/$src.h"
    [ -f "$f" ] && say "     · $src $(grep -q 'QML_ELEMENT' "$f" && echo '(tipo QML)' || echo '(base interna)')"
  done

  say; say "${c_b}Python${c_0}"
  if have python3; then
    ok "python3 $(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
    python3 -c 'import tomllib' 2>/dev/null && ok "tomllib (Python ≥ 3.11, lo usa palette-apply.py)" || bad "sin tomllib: palette-apply.py necesita Python ≥ 3.11"
  else bad "python3 no encontrado (palette-apply.py y keybinds_tool.py no funcionarán)"; fi
  for f in tools/palette-apply.py Keybinds/keybinds_tool.py; do
    [ -f "$ROOT/$f" ] && say "     · $f"
  done

  say; say "${c_b}Bash${c_0}"
  for f in OozeAudio/backend/audio.sh PackageSearch/installed.sh tools/live-optimize.sh tools/online-wallpapers.sh tools/check.sh tools/install-wallpapers.sh; do
    [ -f "$ROOT/$f" ] && say "     · $f"
  done

  say; say "${c_b}Programas externos que invoca el shell${c_0}"
  say "  ${c_dim}(obligatorio = el shell no arranca; los demás activan funciones concretas)${c_0}"
  chk() { have "$1" && ok "$1 ${c_dim}— $2${c_0}" || bad "$1 ${c_dim}— $2${c_0}"; }
  chk quickshell   "obligatorio"
  chk hyprctl      "Hyprland (workspaces, ventanas)"
  chk niri         "niri (ventanas, blur)"
  chk mmsg         "MangoWC"
  chk matugen      "paleta automática desde el wallpaper"
  chk cava         "visualizador de audio"
  chk wpctl        "volumen (PipeWire)"
  chk pw-cli       "OozeAudio (salidas virtuales)"
  chk pw-dump      "OozeAudio"
  chk pw-link      "OozeAudio"
  chk jq           "OozeAudio"
  chk nmcli        "red"
  chk brightnessctl "brillo"
  chk cliphist     "historial del portapapeles"
  chk wl-copy      "portapapeles"
  chk mpv          "wallpapers animados"
  chk ffmpeg       "optimizar videos (live-optimize.sh)"
  chk tmux         "sesiones en el launcher"
  chk rofi         "launcher alterno"
  chk fc-list      "diagnóstico de fuentes"
  chk fc-cache     "fuentes"
}

# ─────────────────────────────────────────────────────────────── fuentes
cmd_fonts() {
  head_ "Fuentes: fontconfig"
  if ! have fc-list; then bad "fc-list no está en el PATH"; else
    for fam in "Nunito" "M PLUS Rounded 1c" "Zen Maru Gothic" "Kosugi Maru" "Fredoka" "JetBrainsMono Nerd Font" "Symbols Nerd Font Mono" "Noto Color Emoji"; do
      n=$(fc-list "$fam" 2>/dev/null | wc -l)
      [ "$n" -gt 0 ] && ok "$fam  ($n archivos)" || bad "$fam  — fontconfig NO la ve"
    done
    say
    say "  ${c_dim}Si alguna sale ✘: con home-manager falta  fonts.fontconfig.enable = true;"
    say "  y después  home-manager switch  (ver tools/fonts/fonts.nix.example).${c_0}"
  fi
  head_ "Fuentes: lo que ve el shell (necesita OozeShell corriendo)"
  if [ -n "$(shell_pids)" ]; then
    "$QS" ipc -p "$ROOT/shell.qml" call theme fonts 2>&1 | sed 's/^/  /' || true
    say "  ${c_dim}Para releer sin reiniciar:  $QS ipc -p $ROOT/shell.qml call -- theme fontsrefresh${c_0}"
  else
    say "  (el shell no está corriendo)"
  fi
}

# ─────────────────────────────────────────────────────────────── run
launch_shell() {
  local mode="$1" log="$2" cfg="${3:-}"
  local -a env_extra=()
  if [ "$mode" = native ]; then
    env_extra+=("QML_IMPORT_PATH=$PREFIX${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}")
  else

    env_extra+=("QML_IMPORT_PATH=$(printf '%s' "${QML_IMPORT_PATH:-}" | tr ':' '\n' | grep -v "$PREFIX" | paste -sd: -)")
  fi
  [ "${BENCH_TIMING:-0}" = 1 ] && env_extra+=("QSG_RENDER_TIMING=1")
  mkdir -p "$(dirname "$log")"
  if [ -n "$cfg" ]; then
    env "${env_extra[@]}" setsid "$QS" -c "$cfg" >"$log" 2>&1 &
  else
    env "${env_extra[@]}" setsid "$QS" -p "$ROOT/shell.qml" >"$log" 2>&1 &
  fi
  echo $!
}

cmd_run() {
  local native=1 rebuild=0 cfg="" replace=0
  while [ $# -gt 0 ]; do case "$1" in
    --no-native) native=0 ;;
    --rebuild)   rebuild=1 ;;
    --config)    cfg="${2:-}"; shift ;;
    --replace)   replace=1 ;;
    *) bad "opción desconocida: $1"; return 2 ;;
  esac; shift; done

  have "$QS" || { bad "No encuentro '$QS' en el PATH."; return 1; }
  if [ "$native" = 1 ]; then
    if [ "$rebuild" = 1 ] || ! native_built; then cmd_build || { bad "falló la compilación; sigo en QML puro"; native=0; }; fi
  fi
  if [ -n "$(shell_pids)" ]; then
    if [ "$replace" = 1 ]; then stop_shell; else bad "OozeShell ya está corriendo (usa --replace o 'stop')."; return 1; fi
  fi

  mkdir -p "$LOGDIR"
  local log="$LOGDIR/run-$(date +%H%M%S).log" mode=native
  [ "$native" = 1 ] || mode=qml
  head_ "Arrancando OozeShell ($([ "$mode" = native ] && echo 'C++ nativo' || echo 'QML puro'))"
  say "  log: $log"
  local pid; pid=$(launch_shell "$mode" "$log" "$cfg")
  sleep 3
  if ! kill -0 "$pid" 2>/dev/null; then bad "quickshell se cerró al arrancar. Últimas líneas:"; tail -n 15 "$log" | sed 's/^/    /'; return 1; fi
  grep -h "núcleo nativo\|\[theme\] fuentes" "$log" | sed 's/^/  /' || true
  ok "corriendo (pid $pid).  Ctrl+C no lo detiene: usa  bash tools/ooze-run.sh stop"
}

# ─────────────────────────────────────────────────────────────── bench
CLK=$(getconf CLK_TCK 2>/dev/null || echo 100)

proc_ticks() { awk '{print $14+$15}' "/proc/$1/stat" 2>/dev/null; }
proc_rss_kb() { awk '/VmRSS/{print $2}' "/proc/$1/status" 2>/dev/null; }


bench_pass() {
  local mode="$1" secs="$2" cycles="$3"
  mkdir -p "$LOGDIR"
  local log="$LOGDIR/bench-$mode.log"
  local t0 t1 pid
  t0=$(date +%s.%N)
  pid=$(BENCH_TIMING=1 launch_shell "$mode" "$log")


  local up=0
  for _ in $(seq 1 100); do
    kill -0 "$pid" 2>/dev/null || break
    if "$QS" ipc -p "$ROOT/shell.qml" show >/dev/null 2>&1; then up=1; break; fi
    sleep 0.2
  done
  t1=$(date +%s.%N)
  if [ "$up" = 0 ]; then echo "FAIL"; kill "$pid" 2>/dev/null; return 1; fi
  local startup; startup=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
  sleep 2


  local base_lines; base_lines=$(wc -l <"$log")
  local tick0 wall0; tick0=$(proc_ticks "$pid"); wall0=$(date +%s.%N)


  local cpu_peak=0 rss_peak=0 prev_t=$tick0 prev_w=$wall0
  (
    for i in $(seq 1 "$cycles"); do
      for m in apps windows run files; do
        "$QS" ipc -p "$ROOT/shell.qml" call launcher open "$m" >/dev/null 2>&1
        sleep 0.55
        "$QS" ipc -p "$ROOT/shell.qml" call launcher close >/dev/null 2>&1
        sleep 0.35
      done
    done
  ) &
  local driver=$!
  local end; end=$(awk -v n="$(date +%s.%N)" -v s="$secs" 'BEGIN{print n+s}')
  while :; do
    now=$(date +%s.%N)
    awk -v n="$now" -v e="$end" 'BEGIN{exit !(n<e)}' || break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
    t=$(proc_ticks "$pid"); w=$(date +%s.%N)
    [ -n "$t" ] || break
    cpu=$(awk -v a="$prev_t" -v b="$t" -v w0="$prev_w" -v w1="$w" -v c="$CLK" 'BEGIN{d=w1-w0; if(d<=0)d=1; printf "%.1f", (b-a)/c/d*100}')
    awk -v c="$cpu" -v p="$cpu_peak" 'BEGIN{exit !(c>p)}' && cpu_peak=$cpu
    r=$(proc_rss_kb "$pid"); [ -n "$r" ] && [ "$r" -gt "$rss_peak" ] && rss_peak=$r
    prev_t=$t; prev_w=$w
  done
  kill "$driver" 2>/dev/null; wait "$driver" 2>/dev/null
  "$QS" ipc -p "$ROOT/shell.qml" call launcher close >/dev/null 2>&1

  local tick1 wall1; tick1=$(proc_ticks "$pid"); wall1=$(date +%s.%N)
  local cpu_avg
  cpu_avg=$(awk -v a="$tick0" -v b="${tick1:-$tick0}" -v w0="$wall0" -v w1="$wall1" -v c="$CLK" 'BEGIN{d=w1-w0; if(d<=0)d=1; printf "%.1f", (b-a)/c/d*100}')


  local fr; fr=$(tail -n +"$((base_lines+1))" "$log" | awk '
    /[Ff]rame rendered/ {
      if (match($0, /in [0-9.]+ ms/)) { s=substr($0,RSTART+3,RLENGTH-6)+0; v[n++]=s; sum+=s; if(s>mx)mx=s; if(s>16.6)over++ }
    }
    END {
      if (n==0) { print "0 0 0 0 0"; exit }

      for(i=0;i<n;i++) a[i]=v[i]
      for(i=1;i<n;i++){x=a[i];j=i-1;while(j>=0&&a[j]>x){a[j+1]=a[j];j--}a[j+1]=x}
      p=a[int((n-1)*0.95)]
      printf "%d %.2f %.2f %.2f %d\n", n, sum/n, p, mx, over
    }')

  kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null
  echo "$startup $cpu_avg $cpu_peak $(awk -v k="$rss_peak" 'BEGIN{printf "%.0f", k/1024}') $fr"
}

backend_startups() {
  head_ "Arranque de los backends de Python / Bash"
  tm() {
    local label="$1"; shift
    local best=999999 a b d
    for _ in 1 2 3; do
      a=$(date +%s%N); "$@" >/dev/null 2>&1; b=$(date +%s%N)
      d=$(( (b-a)/1000000 )); [ "$d" -lt "$best" ] && best=$d
    done
    printf '  %-34s %6d ms\n' "$label" "$best"
  }
  have python3 && tm "palette-apply.py --help" python3 "$ROOT/tools/palette-apply.py" --help
  tm "installed.sh (pacman)" bash "$ROOT/PackageSearch/installed.sh" 1
  say "  ${c_dim}(audio.sh necesita PipeWire en vivo y keybinds_tool.py toca tu config de Hyprland: no se miden)${c_0}"
}

cmd_bench() {
  local secs=25 cycles=20 yes=0 only=""
  while [ $# -gt 0 ]; do case "$1" in
    --secs)   secs="${2:-25}"; shift ;;
    --cycles) cycles="${2:-20}"; shift ;;
    --yes)    yes=1 ;;
    --only)   only="${2:-}"; shift ;;
    *) bad "opción desconocida: $1"; return 2 ;;
  esac; shift; done

  have "$QS" || { bad "No encuentro '$QS'."; return 1; }
  if [ "$only" != qml ] && ! native_built; then cmd_build || { bad "sin módulo nativo no hay nada que comparar"; return 1; }; fi

  if [ -n "$(shell_pids)" ]; then
    if [ "$yes" != 1 ]; then
      printf '%sEl benchmark cierra tu OozeShell actual (la barra desaparece unos minutos). ¿Seguir? [s/N] %s' "$c_b" "$c_0"
      read -r r; case "$r" in s|S|y|Y) ;; *) say "cancelado."; return 1 ;; esac
    fi
    stop_shell
  fi

  head_ "Benchmark — $secs s por pasada, $cycles ciclos de launcher (4 modos cada uno)"
  say "  ${c_dim}Mientras corre no toques el teclado/ratón; cada ciclo abre y cierra el launcher por IPC.${c_0}"

  local -a modes=(qml native)
  [ -n "$only" ] && modes=("$only")
  declare -A R
  for m in "${modes[@]}"; do
    say "  → pasada: $m …"
    R[$m]="$(bench_pass "$m" "$secs" "$cycles")"
    [ "${R[$m]}" = FAIL ] && bad "$m: el shell no arrancó (revisa $LOGDIR/bench-$m.log)"
    stop_shell
  done

  head_ "Resultados"
  printf '  %-8s %9s %8s %8s %9s %7s %8s %8s %8s %9s\n' "modo" "arranque" "CPU med" "CPU pico" "RSS pico" "frames" "ms med" "ms p95" "ms máx" ">16.6ms"
  for m in "${modes[@]}"; do
    [ "${R[$m]}" = FAIL ] && continue
    read -r st ca cp rss n fa f95 fmx fo <<<"${R[$m]}"
    printf '  %-8s %8ss %7s%% %7s%% %7sMB %7s %8s %8s %8s %9s\n' "$m" "$st" "$ca" "$cp" "$rss" "$n" "$fa" "$f95" "$fmx" "$fo"
  done
  say
  say "  ${c_dim}frames = los que Qt reportó con QSG_RENDER_TIMING durante la carga. Si es 0, tu Qt no imprime ese"
  say "  log (o el render va por un camino distinto): fíjate entonces en CPU/RSS."
  say "  Logs completos: $LOGDIR/bench-{qml,native}.log${c_0}"
  grep -h "núcleo nativo" "$LOGDIR"/bench-*.log 2>/dev/null | sort -u | sed 's/^/  /'

  backend_startups
}

# ─────────────────────────────────────────────────────────────── main
case "${1:-help}" in
  build)    shift; cmd_build "$@" ;;
  run)      shift; cmd_run "$@" ;;
  backends) cmd_backends ;;
  fonts)    cmd_fonts ;;
  bench)    shift; cmd_bench "$@" ;;
  stop)     stop_shell; ok "OozeShell detenido" ;;
  *)        sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
