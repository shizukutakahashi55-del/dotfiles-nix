# Tools/online-wallpapers.sh — busca wallpapers en línea para el modo "Online"
# de Services/Walls/Walls.qml. También sirve a mano para probar una fuente.

set -u
SRC="${1:-wallhaven}"; Q="${2:-}"; SORT="${3:-toplist}"; CAT="${4:-110}"
RES="${5:-1920x1080}"; PAGE="${6:-1}"; TD="${7:-$HOME/.cache/oozeshell/online/thumbs}"; PUR="${8:-100}"

command -v curl >/dev/null && command -v jq >/dev/null || { echo "faltan curl/jq" >&2; exit 1; }
case "$PAGE" in ''|*[!0-9]*) PAGE=1 ;; esac
mkdir -p "$TD"
UA="OozeShell/1.0 (wallpaper picker)"

JSON=""
case "$SRC" in
  wallhaven)

    case "$SORT" in toplist|hot|random|date_added|views|favorites|relevance) ;; *) SORT=toplist ;; esac
    case "$CAT"  in [01][01][01]) [ "$CAT" = 000 ] && CAT=110 ;; *) CAT=110 ;; esac
    case "$RES"  in [0-9]*x[0-9]*|any) ;; *) RES=1920x1080 ;; esac
    [ -n "$Q" ] && [ "$SORT" = toplist ] && SORT=relevance
    ATL=""; [ "$RES" != any ] && ATL="&atleast=${RES}"

    case "$PUR" in [01][01][01]) ;; *) PUR=100 ;; esac
    [ -z "${OOZE_WH_KEY:-}" ] && PUR="${PUR:0:2}0"
    [ "$PUR" = 000 ] && PUR=100
    ENC=$(jq -rn --arg q "$Q" '$q|@uri')
    URL="https://wallhaven.cc/api/v1/search?q=${ENC}&categories=${CAT}&purity=${PUR}&sorting=${SORT}${ATL}&page=${PAGE}"

    [ "$SORT" = random ] && URL="$URL&seed=$(printf %s "$Q$CAT$PUR" | md5sum | cut -c1-6)"
    HDR=()
    [ -n "${OOZE_WH_KEY:-}" ] && HDR=(-H "X-API-Key: $OOZE_WH_KEY")
    JSON=$(curl -fsSL -m 25 -A "$UA" "${HDR[@]}" "$URL") || exit 3
    ROWS=$(printf %s "$JSON" | jq -r '.data[]? | [("wallhaven-" + .id + "." + (.file_type // "image/jpeg" | split("/")[1] | sub("jpeg";"jpg"))), .path, .thumbs.large, ((.resolution // "") + " · wallhaven")] | @tsv') || exit 3
    ;;
  bing)

    [ "$PAGE" -gt 1 ] && exit 0
    MKT="${OOZE_BING_MKT:-en-US}"
    URL="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=${MKT}"
    JSON=$(curl -fsSL -m 25 -A "$UA" "$URL") || exit 3
    ROWS=$(printf %s "$JSON" | jq -r '.images[]? | [("bing-" + .startdate + "-" + (.hsh[0:8]) + ".jpg"), ("https://www.bing.com" + .urlbase + "_UHD.jpg"), ("https://www.bing.com" + .urlbase + "_640x360.jpg"), ((.title // "Bing") + " · Bing")] | @tsv') || exit 3
    ;;
  *) echo "fuente desconocida: $SRC" >&2; exit 1 ;;
esac


n=0
while IFS=$'\t' read -r NAME FULL THUMB LABEL; do
  [ -n "$NAME" ] && [ -n "$FULL" ] && [ -n "$THUMB" ] || continue
  T="$TD/${NAME%.*}.jpg"
  (
    if [ -s "$T" ] || curl -fsSL -m 25 -A "$UA" -o "$T.part" "$THUMB" 2>/dev/null; then
      [ -s "$T.part" ] && mv -f "$T.part" "$T"
      [ -s "$T" ] && printf '%s\t%s\t%s\t%s\n' "$NAME" "$FULL" "$T" "$LABEL"
    fi
    rm -f "$T.part"
  ) &
  n=$((n + 1))
  [ $((n % 4)) -eq 0 ] && wait
done <<< "$ROWS"
wait
exit 0
