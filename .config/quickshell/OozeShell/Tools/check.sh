# Tools/check.sh — chequeos rápidos de OozeShell (no reemplaza probar en Quickshell).
# Uso:  cd OozeShell && bash Tools/check.sh

set -u
cd "$(dirname "$0")/.."
fail=0

echo "── 1. páginas del registro"
grep -oE 'page: *"[^"]+\.qml"' Settings/SettingsRegistry.qml | sed -E 's/.*"([^"]+)"/\1/' | while read -r f; do
  if [ -f "Settings/$f" ]; then echo "  ok   $f"; else echo "  FALTA Settings/$f"; exit 1; fi
done || fail=1

echo "── 2. claves de traducción"
keys=$( { grep -ohE '(titleKey|hintKey|labelKey): *"[^"]+"' Settings/SettingsRegistry.qml
          grep -rohE 'Translations\.t\("[^"]+"\)' --include=*.qml .
        } | sed -E 's/.*"([^"]+)".*/\1/' | sort -u )
missing=0
for k in $keys; do
  for lang in Es En; do
    if ! grep -qE "^[[:space:]]*$k:" "Services/Lang/languages/Lang$lang.qml"; then
      echo "  falta '$k' en Lang$lang.qml"; missing=1
    fi
  done
done
[ $missing -eq 0 ] && echo "  ok   todas las claves existen en es/en" || fail=1

echo "── 3. qmllint"
if command -v qmllint >/dev/null 2>&1; then
  cand="$(
    for bin in qmllint quickshell qs; do
      b=$(command -v "$bin" 2>/dev/null) || continue
      printf '%s:' "$(dirname "$(dirname "$(readlink -f "$b")")")/lib/qt-6/qml"
    done
    printf '%s:%s:%s:%s' "${QML_IMPORT_PATH:-}" "${QML2_IMPORT_PATH:-}" \
      "${NIXPKGS_QT6_QML_IMPORT_PATH:-}" "${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/qml"
  )"
  imports=(); seen=":"
  IFS=: read -ra cand_dirs <<< "$cand"
  for d in "${cand_dirs[@]}"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case "$seen" in *":$d:"*) continue ;; esac
    seen="$seen$d:"; imports+=("-I" "$d")
  done

  lint_out=$(qmllint "${imports[@]}" $(find . -name '*.qml') 2>&1)
  errors=$(printf '%s\n' "$lint_out" | grep -E '^Error' || true)
  n_err=$(printf '%s\n' "$errors" | grep -c '^Error' || true)
  n_warn=$(printf '%s\n' "$lint_out" | grep -cE '^Warning' || true)
  n_info=$(printf '%s\n' "$lint_out" | grep -cE '^Info' || true)
  if [ "$n_err" -gt 0 ]; then
    printf '%s\n' "$errors" | head -20 | sed 's/^/  /'
    fail=1
  fi
  echo "  $n_err errores, $n_warn avisos, $n_info notas  —  $((${#imports[@]} / 2)) rutas -I"
  printf '%s\n' "$lint_out" | grep -oE '\[[a-z-]+\]$' | sort | uniq -c | sort -rn | head -6 | sed 's/^/    /'
else
  echo "  (qmllint no está instalado: se omite)"
fi

exit $fail
