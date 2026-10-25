# Tools/build-native.sh — compila el módulo C++ `OozeShell.Native` y lo instala.
# Uso:   bash Tools/build-native.sh [PREFIJO]

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v cmake >/dev/null 2>&1; then
  echo "No encuentro cmake." >&2
  if command -v nix-shell >/dev/null 2>&1; then
    echo "En NixOS:  nix-shell $ROOT/native/shell.nix --run 'bash $ROOT/Tools/build-native.sh'" >&2
  fi
  exit 1
fi

cd "$ROOT/native/AnimationController"

PREFIX="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/qml}"
BUILD="build"

PREFIX_ARGS=()
if [ -n "${IN_NIX_SHELL:-}" ]; then
  NIX_QT=""
  for d in ${buildInputs:-} ${nativeBuildInputs:-} ${propagatedBuildInputs:-} $(printf '%s' "${CMAKE_PREFIX_PATH:-}" | tr ';:' '  '); do
    case "$d" in /nix/store/*) ;; *) continue ;; esac
    case ";$NIX_QT;" in *";$d;"*) continue ;; esac
    [ -d "$d/lib/cmake" ] && NIX_QT="${NIX_QT:+$NIX_QT;}$d"
  done
  if [ -n "$NIX_QT" ]; then
    PREFIX_ARGS=("-DCMAKE_PREFIX_PATH=$NIX_QT" "-DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF" "-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF")
    export CMAKE_PREFIX_PATH="$NIX_QT"
    unset Qt6_DIR Qt6Core_DIR Qt6CoreTools_DIR
  fi
elif [ -z "${IN_NIX_SHELL:-}" ] && command -v pkg-config >/dev/null 2>&1; then
  QT_QML="$(pkg-config --variable=prefix Qt6Qml 2>/dev/null || true)"
  QT_CORE="$(pkg-config --variable=prefix Qt6Core 2>/dev/null || true)"
  if [ -n "$QT_CORE" ]; then
    P="$QT_CORE"
    [ -n "$QT_QML" ] && P="$P;$QT_QML"
    PREFIX_ARGS=("-DCMAKE_PREFIX_PATH=$P")
  fi
fi

if [ -f "$BUILD/CMakeCache.txt" ] && grep -q "/etc/profiles\|home-manager-path\|/run/current-system/sw" "$BUILD/CMakeCache.txt"; then
  rm -rf "$BUILD"
fi

cmake -S . -B "$BUILD" -DCMAKE_BUILD_TYPE=Release "${PREFIX_ARGS[@]}"
cmake --build "$BUILD" --parallel

mkdir -p "$PREFIX/OozeShell"
rm -rf "$PREFIX/OozeShell/Native"
cp -r "$BUILD/qml/OozeShell/Native" "$PREFIX/OozeShell/Native"

echo
echo "Instalado en: $PREFIX/OozeShell/Native"
echo "Falta (una vez):  export QML_IMPORT_PATH=\"$PREFIX\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}\""
echo "Al arrancar, OozeShell loguea:  [theme] núcleo nativo: activo"
