#!/usr/bin/env bash
# tools/check.sh — chequeos rápidos de OozeShell (no reemplaza probar en Quickshell).
#   1. Cada `page:` de SettingsRegistry existe.
#   2. Cada clave de traducción del registro de Ajustes existe
#      en los 4 idiomas (es, en, id, ja).
#   3. `qmllint` sobre todos los .qml, si está instalado.
# Uso:  cd OozeShell && bash tools/check.sh
set -u
cd "$(dirname "$0")/.."
fail=0

echo "── 1. páginas del registro"
grep -oE 'page: *"[^"]+\.qml"' SETTINGS/SettingsRegistry.qml | sed -E 's/.*"([^"]+)"/\1/' | while read -r f; do
  if [ -f "SETTINGS/$f" ]; then echo "  ok   $f"; else echo "  FALTA SETTINGS/$f"; exit 1; fi
done || fail=1

echo "── 2. claves de traducción"
keys=$( { grep -ohE '(titleKey|hintKey|labelKey): *"[^"]+"' SETTINGS/SettingsRegistry.qml
          grep -ohE 'Translations\.t\("[^"]+"\)' SETTINGS/pages/*.qml SETTINGS/Settings*.qml 2>/dev/null
        } | sed -E 's/.*"([^"]+)".*/\1/' | sort -u )
missing=0
for k in $keys; do
  for lang in Es En Id Ja; do
    if ! grep -qE "^[[:space:]]*$k:" "LANG/languages/Lang$lang.qml"; then
      echo "  falta '$k' en Lang$lang.qml"; missing=1
    fi
  done
done
[ $missing -eq 0 ] && echo "  ok   todas las claves existen en es/en/id/ja" || fail=1

echo "── 3. qmllint"
if command -v qmllint >/dev/null 2>&1; then
  qmllint $(find . -name '*.qml') 2>&1 | grep -v "^$" | head -60
else
  echo "  (qmllint no está instalado: se omite)"
fi

exit $fail
