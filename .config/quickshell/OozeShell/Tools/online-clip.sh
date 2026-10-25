# Tools/online-clip.sh
set -u
REF="${1:-}"; JOBS="${ONLINE_CLIP_JOBS:-4}"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
command -v ffmpeg >/dev/null || { echo "falta ffmpeg" >&2; exit 1; }
VF='fps=12,scale=320:-2:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer'

gen() {
  P="$1"; C="$2"; U="$3"
  [ -s "$C" ] && { echo "$P"; return; }
  mkdir -p "$(dirname "$C")"
  T="$C.part.gif"
  H=(-user_agent "$UA" -rw_timeout 15000000)
  [ -n "$REF" ] && H+=(-headers "Referer: $REF"$'\r\n')
  timeout 60 ffmpeg -nostdin -y -v error "${H[@]}" -t 3 -i "$U" -vf "$VF" -loop 0 "$T" 2>/dev/null
  if [ ! -s "$T" ]; then
    L="$C.src"
    curl -fsSL --connect-timeout 8 -m 45 --max-filesize 80000000 -A "$UA" ${REF:+-e "$REF"} -o "$L" "$U" 2>/dev/null \
      && timeout 60 ffmpeg -nostdin -y -v error -t 3 -i "$L" -vf "$VF" -loop 0 "$T" 2>/dev/null
    rm -f "$L"
  fi
  if [ -s "$T" ]; then mv -f "$T" "$C" && echo "$P"; else rm -f "$T"; fi
}

while IFS=$'\t' read -r P C U; do
  [ -n "$P" ] && [ -n "$C" ] && [ -n "$U" ] || continue
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
  gen "$P" "$C" "$U" &
done
wait
exit 0
