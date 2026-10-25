# Tools/ooze-capture.sh
set -u
set -o pipefail
SUB="${1:-}"
[ "$#" -gt 0 ] && shift

resolve_dir() {
  local d="$1" key="$2" fallback="$3" sub="$4" b
  if [ -z "$d" ]; then
    b="$(xdg-user-dir "$key" 2>/dev/null)"
    [ -z "$b" ] && b="$HOME/$fallback"
    d="$b/$sub"
  fi
  case "$d" in
    "~") d="$HOME" ;;
    "~/"*) d="$HOME/${d#\~/}" ;;
  esac
  mkdir -p "$d" 2>/dev/null
  printf %s "$d"
}

stamp() { date +"$1" | tr '/' '_'; }

unique_path() {
  local dir="$1" name="$2" ext="$3" f n=1
  f="$dir/$name.$ext"
  while [ -e "$f" ]; do f="$dir/${name}_$n.$ext"; n=$((n + 1)); done
  printf %s "$f"
}

warn() { notify-send -u critical -a OozeShell "$CAP_T_TITLE" "$1"; }
info() { [ "${CAP_NOTIFY:-1}" = 1 ] && notify-send -a OozeShell "$CAP_T_TITLE" "$1"; return 0; }

mime_of() { case "$1" in jpeg) echo image/jpeg ;; *) echo image/png ;; esac; }

shot() {
  command -v grim >/dev/null 2>&1 || { warn "$CAP_T_MISSFULL"; exit 127; }
  local args=() fmt="${CAP_FMT:-png}" f dir name
  [ -n "${CAP_GEO:-}" ] && args+=(-g "$CAP_GEO")
  [ "${CAP_CURSOR:-0}" = 1 ] && args+=(-c)
  case "$fmt" in
    jpeg) args+=(-t jpeg -q "${CAP_Q:-90}") ;;
    *) args+=(-t png) ;;
  esac

  if [ "${CAP_COPY_ONLY:-0}" = 1 ]; then
    command -v wl-copy >/dev/null 2>&1 || { warn "$CAP_T_MISSCOPY"; exit 127; }
    if grim "${args[@]}" - | wl-copy --type "$(mime_of "$fmt")"; then
      info "$CAP_T_COPIED"
    else
      warn "$CAP_T_COPYFAIL"
      exit 1
    fi
    return
  fi

  dir="$(resolve_dir "${CAP_DIR:-}" PICTURES Pictures Screenshots)"
  name="$(stamp "$CAP_PATTERN")"
  f="$(unique_path "$dir" "$name" "$CAP_EXT")"
  if grim "${args[@]}" "$f"; then
    if [ "${CAP_CLIP:-0}" = 1 ] && command -v wl-copy >/dev/null 2>&1; then
      wl-copy --type "$(mime_of "$fmt")" < "$f"
    fi
    info "$f"
  else
    warn "$CAP_T_SAVEFAIL"
    exit 1
  fi
}

recpath() {
  local dir name final tmp
  dir="$(resolve_dir "${CAP_DIR:-}" VIDEOS Videos Recordings)"
  name="$(stamp "$CAP_PATTERN")"
  final="$(unique_path "$dir" "$name" "$CAP_EXT")"
  tmp="${XDG_CACHE_HOME:-$HOME/.cache}/oozeshell/rec/$name-$$"
  mkdir -p "$tmp" || exit 1
  printf '%s\n%s\n' "$final" "$tmp"
}

default_node() {
  local kind="$1" n=""
  if command -v pactl >/dev/null 2>&1; then
    n="$(pactl "get-default-$kind" 2>/dev/null)"
  fi
  if [ -z "$n" ] && command -v wpctl >/dev/null 2>&1; then
    case "$kind" in
      sink) n="$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)".*/\1/p' | head -n1)" ;;
      source) n="$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)".*/\1/p' | head -n1)" ;;
    esac
  fi
  printf %s "$n"
}

audio_device() {
  local s dev=""
  case "$1" in
    system)
      s="$(default_node sink)"
      [ -n "$s" ] && dev="$s.monitor"
      if command -v pactl >/dev/null 2>&1; then
        if [ -z "$dev" ] || ! pactl list short sources 2>/dev/null | cut -f2 | grep -qx "$dev"; then
          dev="$(pactl list short sources 2>/dev/null | cut -f2 | grep '\.monitor$' | head -n1)"
        fi
      fi
      ;;
    mic)
      dev="$(default_node source)"
      if command -v pactl >/dev/null 2>&1; then
        if [ -z "$dev" ] || ! pactl list short sources 2>/dev/null | cut -f2 | grep -qx "$dev"; then
          dev="$(pactl list short sources 2>/dev/null | cut -f2 | grep -v '\.monitor$' | head -n1)"
        fi
      fi
      ;;
  esac
  printf %s "$dev"
}

recseg() {
  command -v wf-recorder >/dev/null 2>&1 || exit 127
  local args=(-f "$CAP_OUT" -r "${CAP_FPS:-30}" -y) dev log
  log="${XDG_CACHE_HOME:-$HOME/.cache}/oozeshell/rec.log"
  mkdir -p "$(dirname "$log")"
  if [ -n "${CAP_GEO:-}" ]; then
    args+=(-g "$CAP_GEO")
  elif [ -n "${CAP_MON:-}" ]; then
    args+=(-o "$CAP_MON")
  fi
  case "${CAP_CODEC:-x264}" in
    vaapi) args+=(-c h264_vaapi -d "${CAP_DRI:-/dev/dri/renderD128}" -p "qp=${CAP_CRF:-22}") ;;
    nvenc) args+=(-c h264_nvenc -p preset=p5 -p tune=hq -p rc=vbr -p "cq=${CAP_CRF:-24}" -p b=0 -p profile=high) ;;
    vp8) args+=(-c libvpx -p "crf=${CAP_CRF:-30}" -p b=0 -p deadline=realtime -p cpu-used=6) ;;
    *) args+=(-c libx264 -p "crf=${CAP_CRF:-24}" -p "preset=${CAP_PRESET:-veryfast}") ;;
  esac
  if [ "${CAP_AUDIO:-none}" != none ]; then
    dev="$(audio_device "$CAP_AUDIO")"
    if [ -n "$dev" ]; then args+=("--audio=$dev"); else args+=(--audio); fi
    case "${CAP_CODEC:-x264}" in
      vp8) args+=(-C libopus) ;;
      *) args+=(-C aac) ;;
    esac
    args+=(-R 48000)
  fi
  {
    printf '%s audio=%s dev=%s\n' "$(date +%T)" "${CAP_AUDIO:-none}" "${dev:-}"
    printf '%q ' wf-recorder "${args[@]}"
    printf '\n'
  } >> "$log"
  exec wf-recorder "${args[@]}" 2>> "$log"
}

recjoin() {
  local final="$CAP_FINAL" tmp list f base ext i=1 rc=0
  [ "$#" -gt 0 ] || exit 1
  tmp="$(dirname "$1")"
  mkdir -p "$(dirname "$final")"
  if [ "$#" -eq 1 ]; then
    mv -f "$1" "$final" || rc=1
  elif command -v ffmpeg >/dev/null 2>&1; then
    list="$tmp/list.txt"
    : > "$list"
    for f in "$@"; do
      printf "file '%s'\n" "$(printf %s "$f" | sed "s/'/'\\\\''/g")" >> "$list"
    done
    ffmpeg -v error -y -f concat -safe 0 -i "$list" -c copy "$final" || rc=1
  else
    base="${final%.*}"
    ext="${final##*.}"
    for f in "$@"; do
      mv -f "$f" "${base}_part$i.$ext" || rc=1
      i=$((i + 1))
    done
  fi
  [ "$rc" -eq 0 ] && rm -rf "$tmp"
  exit "$rc"
}

openfolder() {
  local d
  case "${1:-}" in
    rec) d="$(resolve_dir "${CAP_DIR:-}" VIDEOS Videos Recordings)" ;;
    *) d="$(resolve_dir "${CAP_DIR:-}" PICTURES Pictures Screenshots)" ;;
  esac
  exec xdg-open "$d"
}

case "$SUB" in
  shot) shot ;;
  recpath) recpath ;;
  recseg) recseg ;;
  recjoin) recjoin "$@" ;;
  open) openfolder "$@" ;;
  *) echo "uso: $0 shot|recpath|recseg|recjoin|open" >&2; exit 1 ;;
esac
