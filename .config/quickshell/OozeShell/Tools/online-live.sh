# Tools/online-live.sh
set -u
SRC="${1:-moewalls}"; Q="${2:-}"; SORT="${3:-date_added}"; PAGE="${4:-1}"
TD="${5:-$HOME/.cache/oozeshell/online/thumbs}"
JOBS="${ONLINE_LIVE_JOBS:-8}"

command -v curl >/dev/null && command -v jq >/dev/null || { echo "faltan curl/jq" >&2; exit 1; }
case "$PAGE" in ''|*[!0-9]*) PAGE=1 ;; esac
CACHE="$(dirname "$TD")"
MD="$CACHE/meta"; CD="$CACHE/clips"
mkdir -p "$TD" "$MD" "$CD"
SQ="'"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
PREVIEW_RE='preview|sample|thumb|poster'

case "$SRC" in
  moewalls)      BASE="https://moewalls.com" ;;
  wallpaperwaifu) BASE="https://wallpaperwaifu.com" ;;
  *) echo "fuente desconocida: $SRC" >&2; exit 1 ;;
esac

CURL=(curl -sSL --compressed --connect-timeout 8 --retry 1 -A "$UA" -e "$BASE/")

ENC=$(jq -rn --arg q "$Q" '$q|@uri')
case "$SORT" in
  relevance) [ -n "$Q" ] && ORD=relevance || ORD=date ;;
  date_added) ORD=date ;;
  *) [ -n "$Q" ] && ORD=relevance || ORD=date ;;
esac
URL="$BASE/wp-json/wp/v2/posts?per_page=18&page=${PAGE}&orderby=${ORD}&_embed=wp:featuredmedia&_fields=link,title,content,yoast_head_json,_links,_embedded"
[ -n "$Q" ] && URL="$URL&search=${ENC}"

BODY=$(mktemp)
OUTD=$(mktemp -d)
trap 'rm -rf "$BODY" "$OUTD"' EXIT
CODE=$("${CURL[@]}" -m 30 -o "$BODY" -w '%{http_code}' "$URL") || CODE=000
if [ "$CODE" = 400 ] && [ "$PAGE" -gt 1 ]; then exit 0; fi
if [ "$CODE" = 200 ] && ! jq -e 'type == "array"' "$BODY" >/dev/null 2>&1; then CODE=bad; fi

ROWS=""
if [ "$CODE" = 200 ]; then
ROWS=$(jq -r '
  def vids: [ (.content.rendered // "") | scan("https?:[^\"\\x{27}\\s<>]+\\.(?:mp4|webm)") ];
  .[]? | [
    .link,
    ((.title.rendered // "") | gsub("[\\t\\n]"; " ")),
    ((try (._embedded["wp:featuredmedia"][0] | (.media_details.sizes.medium_large.source_url // .source_url)) catch null)
      // (try .yoast_head_json.og_image[0].url catch null) // ""),
    (first(vids[] | select(test("'"$PREVIEW_RE"'"; "i") | not)) // ""),
    (first(vids[] | select(test("'"$PREVIEW_RE"'"; "i"))) // "")
  ] | map(gsub("\u001f"; " ")) | join("\u001f")' "$BODY") || exit 3
else
  echo "http $CODE en $URL; probando el HTML del sitio" >&2
  if [ -n "$Q" ]; then LURL="$BASE/page/${PAGE}/?s=${ENC}"; else LURL="$BASE/page/${PAGE}/"; fi
  [ "$PAGE" = 1 ] && [ -z "$Q" ] && LURL="$BASE/"
  LCODE=$("${CURL[@]}" -m 30 -o "$BODY" -w '%{http_code}' "$LURL") || LCODE=000
  if [ "$LCODE" = 404 ] && [ "$PAGE" -gt 1 ]; then exit 0; fi
  [ "$LCODE" = 200 ] || { echo "http $LCODE en $LURL" >&2; exit 3; }
  ROWS=$(grep -oE "href=\"${BASE}/[^\"#?]+/\"" "$BODY" | sed -E 's/^href="//; s/"$//' \
    | grep -viE '/(page|tag|category|author|feed|wp-[a-z]+|contact|about|privacy|dmca|terms)(/|$)' \
    | awk -v b="$BASE/" '{ r=substr($0, length(b)+1); sub(/\/$/, "", r); if (r != "" && !s[$0]++) print }' \
    | head -18 | awk '{ printf "%s\037\037\037\037\n", $0 }')
fi

absurl() {
  case "$1" in
    "") ;;
    //*) printf 'https:%s' "$1" ;;
    /*) printf '%s%s' "$BASE" "$1" ;;
    http*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$BASE" "$1" ;;
  esac
}

clean() {
  printf '%s' "$1" | sed -e 's/&#8211;/-/g; s/&#8217;/'"'"'/g; s/&amp;/\&/g; s/&#038;/\&/g; s/&#[0-9]*;//g; s/&[a-z]*;//g' \
    -e 's/ Live Wallpaper$//I; s/ *- *$//; s/\.//g; s/<[^>]*>//g'
}

work() {
  IDX="$1"; LINK="$2"; TITLE="$3"; THUMB="$4"; VID="$5"; PV="$6"
  SLUG=$(basename "${LINK%/}")
  KEY="${SRC}-${SLUG}"
  META="$MD/$KEY.tsv"
  T="$TD/$KEY.jpg"
  if [ -s "$META" ]; then
    IFS=$'\037' read -r MVID MTITLE MPV < "$META"
    [ -n "$VID" ] || VID="$MVID"
    [ -n "$TITLE" ] || TITLE="$MTITLE"
    [ -n "$PV" ] || PV="$MPV"
  fi
  if [ -z "$VID" ] || [ -z "$TITLE" ] || { [ -z "$THUMB" ] && [ ! -s "$T" ]; }; then
    HTML=$("${CURL[@]}" -m 25 "$LINK" 2>/dev/null | sed 's#\\/#/#g')
    ALL=$(printf '%s' "$HTML" | grep -oE "[\"$SQ(=][^\"$SQ <>()\\\\]+\\.(mp4|webm)([?][^\"$SQ <>()\\\\]*)?" | sed -E "s/^[\"$SQ(=]//" | awk '!s[$0]++')
    if [ -z "$VID" ]; then
      VID=$(printf '%s\n' "$ALL" | grep -viE "$PREVIEW_RE" | head -1)
      VID=$(absurl "$VID")
    fi
    if [ -z "$PV" ]; then
      PV=$(printf '%s\n' "$ALL" | grep -iE "$PREVIEW_RE" | head -1)
      PV=$(absurl "$PV")
    fi
    if [ -z "$TITLE" ]; then
      TITLE=$(printf '%s' "$HTML" | grep -oE '<meta[^>]+property="og:title"[^>]+content="[^"]+"' | head -1 | sed -E 's/.*content="([^"]+)".*/\1/')
      [ -n "$TITLE" ] || TITLE="$SLUG"
    fi
    if [ -z "$THUMB" ]; then
      THUMB=$(printf '%s' "$HTML" | grep -oE '<meta[^>]+property="og:image"[^>]+content="[^"]+"' | head -1 | sed -E 's/.*content="([^"]+)".*/\1/')
      THUMB=$(absurl "$THUMB")
    fi
  fi
  [ -n "$TITLE" ] || TITLE="$SLUG"
  [ -n "$VID" ] && printf '%s\037%s\037%s\n' "$VID" "$(clean "$TITLE")" "$PV" > "$META"
  if [ ! -s "$T" ]; then
    [ -n "$THUMB" ] && "${CURL[@]}" -m 25 -o "$T.part" "$THUMB" 2>/dev/null && [ -s "$T.part" ] && mv -f "$T.part" "$T"
    rm -f "$T.part"
  fi
  if [ -s "$T" ]; then
    OUTURL="${VID:-$LINK}"
    EXT="${VID##*.}"; EXT="${EXT%%\?*}"
    case "$EXT" in mp4|webm) ;; *) EXT=mp4 ;; esac
    NAME="${KEY}.${EXT}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$NAME" "$OUTURL" "$T" "$(clean "$TITLE") · $SRC" "$LINK" "$CD/${KEY}.gif" "$PV" > "$OUTD/$IDX.out"
  fi
  : > "$OUTD/$IDX.done"
}

NEXT=0
flush() {
  while [ -e "$OUTD/$NEXT.done" ]; do
    cat "$OUTD/$NEXT.out" 2>/dev/null
    NEXT=$((NEXT + 1))
  done
}

TOTAL=0
while IFS=$'\037' read -r LINK TITLE THUMB VID PV; do
  [ -n "$LINK" ] || continue
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; flush; done
  work "$TOTAL" "$LINK" "$TITLE" "$THUMB" "$VID" "$PV" &
  TOTAL=$((TOTAL + 1))
done <<< "$ROWS"
wait
flush
exit 0
