#!/usr/bin/env bash
# Filtro de luz calida (reemplaza hyprsunset). Usa wlsunset o gammastep.
TEMP=5500
if pgrep -x wlsunset >/dev/null; then
  pkill -x wlsunset; notify-send -i weather-clear "Luz calida" "OFF 🌙"
elif pgrep -x gammastep >/dev/null; then
  pkill -x gammastep; notify-send -i weather-clear "Luz calida" "OFF 🌙"
elif command -v wlsunset >/dev/null; then
  wlsunset -T $((TEMP+1)) -t $TEMP -S 00:00 -s 00:00 & disown
  notify-send -i weather-clear-night "Luz calida" "ON ☀️"
elif command -v gammastep >/dev/null; then
  gammastep -O $TEMP & disown
  notify-send -i weather-clear-night "Luz calida" "ON ☀️"
else
  notify-send "Luz calida" "Instala wlsunset o gammastep"
fi
