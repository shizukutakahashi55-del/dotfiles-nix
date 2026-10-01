#!/usr/bin/env bash
# tools/live-optimize.sh — crea una copia LIVIANA de un video para usarlo de
# wallpaper animado (la usa WALLS/Walls.qml solo; también sirve a mano).
#
# Por qué: mpv decodifica el video a su resolución original y guarda varios
# fotogramas en RAM/VRAM. Un 4K@60 pesa ~8x más en memoria que un 1080p@30 y,
# de fondo de escritorio, no se nota la diferencia.
#
# Salida: ~/.cache/oozeshell/live/opt/<md5 de la ruta original>.mp4
# (mismo nombre que calcula Walls.qml con `printf %s "$ruta" | md5sum`).
#
# Uso:   bash tools/live-optimize.sh VIDEO [ALTO_MAX=1080] [FPS_MAX=30]
# Env:   LIVE_OPT_DIR  carpeta de salida (por defecto la de arriba)
#        LIVE_OPT_CRF  calidad x264 (23 = mejor, 28 = más chico; def. 25)
# Códigos: 0 ok (o ya existía) · 1 error · 2 ya era liviano (no hace falta)
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

# Datos del video original. OJO: ffprobe devuelve los campos en SU orden
# (codec_name, height, avg_frame_rate), no en el que se pide con -show_entries.
IFS=, read -r CODEC H FR < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=height,avg_frame_rate,codec_name -of csv=p=0 "$V" | head -1)
H=${H:-0}
FPS=$(awk -F/ -v f="${FR:-0/1}" 'BEGIN{split(f,a,"/"); print (a[2]>0)? a[1]/a[2] : 0}')

# ¿Hace falta tocar algo? (alto y fps ya dentro del límite y códec H.264)
NEED=0
[ "$H" -gt "$MAXH" ] && NEED=1
awk -v f="$FPS" -v m="$MAXFPS" 'BEGIN{exit !(f>m+0.5)}' && NEED=1
[ "$CODEC" != "h264" ] && NEED=1
if [ "$NEED" -eq 0 ]; then echo "ya es liviano: $V" >&2; exit 2; fi

VF="scale=-2:'min($MAXH,ih)'"
awk -v f="$FPS" -v m="$MAXFPS" 'BEGIN{exit !(f>m+0.5)}' && VF="$VF,fps=$MAXFPS"

TMP="$OUT.part.mp4"
rm -f "$TMP"
# nice/ionice: no debe notarse mientras trabajás
if nice -n 19 ionice -c3 ffmpeg -nostdin -y -v error -i "$V" -an -sn \
     -vf "$VF" -c:v libx264 -preset medium -crf "$CRF" -pix_fmt yuv420p \
     -movflags +faststart "$TMP"; then
  mv -f "$TMP" "$OUT" && echo "$OUT"
else
  rm -f "$TMP"; exit 1
fi
