# Tools/online-download.sh
set -u
SRC="${1:-}"; URL="${2:-}"; DEST="${3:-}"; PAGE="${4:-}"; REF="${5:-}"
[ -n "$URL" ] && [ -n "$DEST" ] || { echo "uso: $0 FUENTE URL DESTINO [PAGINA] [REFERER]" >&2; exit 1; }
HERE=$(dirname "$(readlink -f "$0")")
UA="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
LEN=0

if [ -n "$PAGE" ]; then
  R=$(bash "$HERE/online-resolve.sh" "$SRC" "$PAGE" "$URL")
  if [ -n "$R" ]; then
    URL="${R%%$'\t'*}"
    LEN="${R#*$'\t'}"
  fi
fi
case "$LEN" in ''|*[!0-9]*) LEN=0 ;; esac
case "${URL%%\?*}" in
  *.mp4|*.webm|*.mkv|*.mov) ;;
  *) [ "$LEN" -gt 0 ] || { echo "sin video en $URL" >&2; exit 1; } ;;
esac

mkdir -p "$(dirname "$DEST")"
if [ -s "$DEST" ]; then
  HAVE=$(stat -c %s "$DEST")
  if [ "$LEN" -eq 0 ] || [ "$HAVE" -ge "$LEN" ]; then echo "$DEST"; exit 0; fi
fi

PART="$DEST.part"
OK=1
if command -v aria2c >/dev/null; then
  aria2c -q -x8 -s8 -k2M -c --allow-overwrite=true --user-agent="$UA" ${REF:+--referer="$REF"} \
    -d "$(dirname "$PART")" -o "$(basename "$PART")" "$URL" && OK=0
fi
if [ "$OK" -ne 0 ]; then
  curl -fL --retry 4 --retry-delay 2 --retry-all-errors --connect-timeout 10 \
    --speed-limit 20000 --speed-time 45 -C - -A "$UA" ${REF:+-e "$REF"} -o "$PART" "$URL" && OK=0
fi
if [ "$OK" -ne 0 ]; then
  rm -f "$PART"
  curl -fL --retry 2 --connect-timeout 10 --speed-limit 20000 --speed-time 45 \
    -A "$UA" ${REF:+-e "$REF"} -o "$PART" "$URL" && OK=0
fi
[ "$OK" -eq 0 ] && [ -s "$PART" ] || { rm -f "$PART"; exit 1; }
mv -f "$PART" "$DEST"
echo "$DEST"
