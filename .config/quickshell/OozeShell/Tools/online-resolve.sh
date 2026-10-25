# Tools/online-resolve.sh
set -u
LINK="${2:-}"; FALLBACK="${3:-}"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
[ -n "$LINK" ] || exit 1
BASE=$(printf '%s' "$LINK" | sed -E 's#^(https?://[^/]+).*#\1#')

absurl() {
  case "$1" in
    "") ;;
    //*) printf 'https:%s' "$1" ;;
    /*) printf '%s%s' "$BASE" "$1" ;;
    http*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$BASE" "$1" ;;
  esac
}

probe() {
  u="$1"
  hdr=$(curl -sIL -m 12 --connect-timeout 6 -A "$UA" -e "$BASE/" "$u" 2>/dev/null | tr -d '\r')
  ct=$(printf '%s\n' "$hdr" | grep -i '^content-type:' | tail -1 | tr 'A-Z' 'a-z')
  len=$(printf '%s\n' "$hdr" | grep -i '^content-length:' | tail -1 | tr -dc '0-9')
  case "$ct" in *video/*|*octet-stream*|*binary*) ;; *) return ;; esac
  l=$(printf '%s' "$u" | tr 'A-Z' 'a-z')
  case "$l" in *.mp4*|*.webm*|*.mkv*|*.mov*) ;; *) [ "${len:-0}" -gt 1000000 ] || return ;; esac
  h=0
  case "$l" in
    *4320*|*8k*) h=4320 ;;
    *2160*|*3840*|*4k*) h=2160 ;;
    *1440*|*2560*) h=1440 ;;
    *1080*|*1920*) h=1080 ;;
    *720*|*1280*) h=720 ;;
    *480*) h=480 ;;
  esac
  printf '%s\t%s\t%s\n' "$h" "${len:-0}" "$u"
}
export -f probe
export UA BASE

HTML=$(curl -sSL --compressed -m 25 --connect-timeout 8 -A "$UA" -e "$BASE/" "$LINK" 2>/dev/null | sed 's#\\/#/#g; s/&amp;/\&/g')
SQ="'"
CANDS=$({
  printf '%s\n' "$FALLBACK"
  printf '%s' "$HTML" | grep -oE "[\"$SQ(=][^\"$SQ <>()\\\\]+\\.(mp4|webm)([?][^\"$SQ <>()\\\\]*)?" | sed -E "s/^[\"$SQ(=]//"
  printf '%s' "$HTML" | grep -oE "href=[\"$SQ][^\"$SQ]*(download|/dl/|dl=)[^\"$SQ]*[\"$SQ]" | sed -E "s/^href=[\"$SQ]//; s/[\"$SQ]\$//"
} | grep -v '^$' | while read -r u; do absurl "$u"; echo; done | grep -v '^$' | awk '!s[$0]++' \
  | grep -viE 'preview|sample|thumb|poster' | head -12)

BEST=$(printf '%s\n' "$CANDS" | xargs -P 6 -n1 bash -c 'probe "$1"' _ | sort -t$'\t' -k2,2nr -k1,1nr | head -1)
if [ -n "$BEST" ]; then
  printf '%s\t%s\n' "$(printf '%s' "$BEST" | cut -f3)" "$(printf '%s' "$BEST" | cut -f2)"
  exit 0
fi
case "${FALLBACK%%\?*}" in
  *.mp4|*.webm|*.mkv|*.mov) printf '%s\t0\n' "$FALLBACK" ;;
esac
exit 0
