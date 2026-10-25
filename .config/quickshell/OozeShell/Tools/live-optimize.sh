# Tools/live-optimize.sh — crea una copia LIVIANA de un video para usarlo de wallpaper animado (la usa Services/Walls/Walls.qml solo; también sirve a mano).

set -u
V="${1:-}"; MAXH="${2:-1080}"; MAXFPS="${3:-30}"
[ -n "$V" ] && [ -f "$V" ] || { echo "uso: $0 VIDEO [ALTO_MAX] [FPS_MAX]" >&2; exit 1; }
command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || { echo "faltan ffmpeg/ffprobe" >&2; exit 1; }

DIR="${LIVE_OPT_DIR:-$HOME/.cache/oozeshell/live/opt}"
CRF="${LIVE_OPT_CRF:-25}"
mkdir -p "$DIR"
KEY=$(printf %s "$V" | md5sum | cut -d' ' -f1)
OUT="$DIR/$KEY.mp4"
[ -s "$OUT" ] && { echo "$OUT"; exit 0; }


IFS=, read -r CODEC H FR < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=height,avg_frame_rate,codec_name -of csv=p=0 "$V" | head -1)
H=${H:-0}
FPS=$(awk -F/ -v f="${FR:-0/1}" 'BEGIN{split(f,a,"/"); print (a[2]>0)? a[1]/a[2] : 0}')


NEED=0
[ "$H" -gt "$MAXH" ] && NEED=1
awk -v f="$FPS" -v m="$MAXFPS" 'BEGIN{exit !(f>m+0.5)}' && NEED=1
[ "$CODEC" != "h264" ] && NEED=1
if [ "$NEED" -eq 0 ]; then echo "ya es liviano: $V" >&2; exit 2; fi

VF="scale=-2:'min($MAXH,ih)'"
awk -v f="$FPS" -v m="$MAXFPS" 'BEGIN{exit !(f>m+0.5)}' && VF="$VF,fps=$MAXFPS"

TMP="$OUT.part.mp4"
rm -f "$TMP"

if nice -n 19 ionice -c3 ffmpeg -nostdin -y -v error -i "$V" -an -sn \
     -vf "$VF" -c:v libx264 -preset medium -crf "$CRF" -pix_fmt yuv420p \
     -movflags +faststart "$TMP"; then
  mv -f "$TMP" "$OUT" && echo "$OUT"
else
  rm -f "$TMP"; exit 1
fi
