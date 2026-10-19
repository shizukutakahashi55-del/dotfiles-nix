#!/usr/bin/env bash
# apply.sh — instala la integración Dolphin + OozeShell en cualquier equipo.
# Idempotente: solo escribe lo que falta y respalda lo previo en *.bak.
#
# Uso:  bash apply.sh [--set-default] [--yes]
#   --set-default   además deja Dolphin como gestor predeterminado
#                   (xdg-mime default ... inode/directory) y lo verifica.
#   --yes           no pedir confirmación.

set -u
DOTS="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_ID="org.kde.dolphin.desktop"
SET_DEFAULT=0
ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --set-default) SET_DEFAULT=1 ;;
    --yes) ASSUME_YES=1 ;;
    *) echo "Uso: bash apply.sh [--set-default] [--yes]" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have dolphin; then
  say "Falta dolphin. En NixOS agrégalo declarativamente, p. ej.:"
  say "  environment.systemPackages = with pkgs; [ kdePackages.dolphin ];"
  exit 1
fi
if ! have xdg-mime; then
  say "Falta xdg-mime (paquete xdg-utils)." >&2
  exit 1
fi

backup() { [ -f "$1" ] && [ ! -f "$1.bak" ] && cp -p "$1" "$1.bak" && say "Respaldo: $1.bak"; }

# ─── dolphinrc (defaults OozeShell: sin barra de menú, esquema OozeSoft) ──
if [ ! -f "$HOME/.config/dolphinrc" ]; then
  cp "$DOTS/dolphinrc" "$HOME/.config/dolphinrc"
  say "Instalado ~/.config/dolphinrc (defaults OozeShell)"
else
  say "Ya existe ~/.config/dolphinrc, no se toca (borra ColorScheme para regenerar)"
fi

# ─── Tema OozeShell por defecto: esquema + iconos ─────────────────────
set_kconfig() {  # grupo clave valor archivo
  if have kwriteconfig6; then
    kwriteconfig6 --file "$4" --group "$1" --key "$2" "$3"
  else
    backup "$HOME/.config/$4"
    python3 - "$HOME/.config/$4" "$1" "$2" "$3" <<'PY'
import re, sys
path, group, key, val = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    lines = f.read().splitlines()
out, cur, done = [], None, False
pat = re.compile(r"^\s*\[([^\]]+)\]\s*$")
for ln in lines:
    m = pat.match(ln)
    if m:
        cur = m.group(1)
    elif cur == group and re.match(r"^\s*" + re.escape(key) + r"\s*=", ln):
        ln = key + "=" + val
        done = True
    out.append(ln)
if not done:
    if not any(pat.match(l) and pat.match(l).group(1) == group for l in out):
        out.append("[" + group + "]")
    out.append(key + "=" + val)
with open(path, "w") as f:
    f.write("\n".join(out) + "\n")
PY
  fi
}

CUR_SCHEME="$(grep -m1 -oP '^\s*ColorScheme\s*=\s*\K.*' "$HOME/.config/dolphinrc" 2>/dev/null | tr -d ' ')"
if [ "$CUR_SCHEME" != "OozeSoft" ]; then
  backup "$HOME/.config/dolphinrc"
  set_kconfig UiSettings ColorScheme OozeSoft dolphinrc
  say "dolphinrc: ColorScheme=OozeSoft"
fi

if [ -d /run/current-system/sw/share/icons/Papirus ] || [ -d "$HOME/.local/share/icons/Papirus" ] || [ -d "$HOME/.nix-profile/share/icons/Papirus" ]; then
  set_kconfig Icons Theme Papirus kdeglobals
  say "kdeglobals: Icons=Papirus"
else
  say "Papirus no instalado, se deja el tema de iconos actual"
fi

say "NOTA: OozeSoft.colors lo regenera OozeShell/matugen en cada equipo (~/.local/share/color-schemes/)."

# ─── Gestor predeterminado (solo con --set-default) ───────────────────
if [ "$SET_DEFAULT" -eq 1 ]; then
  if [ "$ASSUME_YES" -eq 0 ]; then
    printf "¿Poner %s como predeterminado para inode/directory? [s/N] " "$DESKTOP_ID"
    read -r ans
    case "$ans" in s|S|s[ií]) ;; *) say "Omitido."; exit 0 ;; esac
  fi
  if xdg-mime default "$DESKTOP_ID" inode/directory; then
    CUR="$(xdg-mime query default inode/directory)"
    if [ "$CUR" = "$DESKTOP_ID" ]; then
      say "Verificado: inode/directory -> $CUR"
    else
      say "Aviso: quedó $CUR, esperado $DESKTOP_ID" >&2
      exit 1
    fi
  else
    say "Falló xdg-mime default" >&2
    exit 1
  fi
else
  say "Actual: inode/directory -> $(xdg-mime query default inode/directory)"
  say "(usa --set-default para dejar Dolphin como predeterminado)"
fi
