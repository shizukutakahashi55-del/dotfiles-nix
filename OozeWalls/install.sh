# SECCION: OOZEWALLS INSTALL
# IPC: build install launcher libs
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

lib_dirs() {
  out=""
  for lib in libwayland-client.so.0 libwayland-cursor.so.0 libwayland-egl.so.1 libxkbcommon.so.0 libX11.so.6 libXcursor.so.1 libXrandr.so.2 libXi.so.6 libGL.so.1 libEGL.so.1 libfontconfig.so.1 libfreetype.so.6; do
    hit="$(find /nix/store -maxdepth 4 -name "$lib" 2>/dev/null | grep -v lib32 | head -1)"
    if [ -n "$hit" ]; then
      out="$out:$(dirname "$hit")"
    fi
  done
  echo "$out" | tr ':' '\n' | grep -v '^$' | sort -u | tr '\n' ':' | sed 's/:$//'
}

echo "OOZEWALLS compilando release"
cargo build --release --manifest-path "$ROOT/Cargo.toml"

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR"
install -m 755 "$ROOT/target/release/oozewalls" "$BIN_DIR/oozewalls-bin"
install -m 755 "$ROOT/target/release/oozewalls-gui" "$BIN_DIR/oozewalls-gui-bin"

echo "OOZEWALLS resolviendo librerias"
LIBS="$(lib_dirs)"

write_wrapper() {
  name="$1"
  cat > "$BIN_DIR/$name" <<EOF
#!/bin/sh
EXTRA="$LIBS"
if [ ! -d "\$(echo "\$EXTRA" | cut -d: -f1)" ]; then
  EXTRA=""
fi
if [ -d /run/opengl-driver/lib ]; then
  EXTRA="/run/opengl-driver/lib:\$EXTRA"
fi
LD_LIBRARY_PATH="\$EXTRA:\$LD_LIBRARY_PATH" exec "$BIN_DIR/$name-bin" "\$@"
EOF
  chmod 755 "$BIN_DIR/$name"
}

write_wrapper oozewalls
write_wrapper oozewalls-gui

install -m 644 "$ROOT/oozewalls.svg" "$ICON_DIR/oozewalls.svg"
sed "s|^Exec=.*|Exec=$BIN_DIR/oozewalls-gui|; s|^Icon=.*|Icon=$ICON_DIR/oozewalls.svg|" \
  "$ROOT/oozewalls-gui.desktop" > "$APP_DIR/oozewalls-gui.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "OOZEWALLS listo busca OozeWalls en el launcher"
