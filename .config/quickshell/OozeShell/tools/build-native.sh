# tools/build-native.sh — compila el módulo C++ `OozeShell.Native` y lo instala.
# Uso:   bash tools/build-native.sh [PREFIJO]

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v cmake >/dev/null 2>&1; then
  echo "No encuentro cmake." >&2
  if command -v nix-shell >/dev/null 2>&1; then
    echo "En NixOS:  nix-shell $ROOT/native/shell.nix --run 'bash $ROOT/tools/build-native.sh'" >&2
  fi
  exit 1
fi

cd "$ROOT/native/AnimationController"

PREFIX="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/qml}"
BUILD="build"

cmake -S . -B "$BUILD" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --parallel

mkdir -p "$PREFIX/OozeShell"
rm -rf "$PREFIX/OozeShell/Native"
cp -r "$BUILD/qml/OozeShell/Native" "$PREFIX/OozeShell/Native"

echo
echo "Instalado en: $PREFIX/OozeShell/Native"
echo "Falta (una vez):  export QML_IMPORT_PATH=\"$PREFIX\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}\""
echo "Al arrancar, OozeShell loguea:  [theme] núcleo nativo: activo"
