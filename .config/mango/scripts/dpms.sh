#!/usr/bin/env bash
# dpms.sh on|off -- apaga/enciende todos los monitores via mmsg
case "$1" in
  off) act=sleep_monitor ;;
  on)  act=wakeup_monitor ;;
  *)   echo "uso: $0 on|off"; exit 1 ;;
esac
for m in $(mmsg get all-monitors | grep -o '"name":"[^"]*"' | cut -d'"' -f4); do
  mmsg dispatch "$act,$m"
done
