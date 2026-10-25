# native/shell.nix — entorno para compilar el módulo C++ en NixOS.
#
#   nix-shell native/shell.nix --run 'bash Tools/build-native.sh'
#
# IMPORTANTE: la Qt de este entorno debe ser LA MISMA que usa tu `quickshell`
# (mismo hash en /nix/store). Si no, Qt rechaza el plugin. Compruébalo con:
#   nix-instantiate --eval -E '(import <nixpkgs> {}).qt6.qtbase.outPath'
#   grep -m1 -o '/nix/store/[^/]*qtbase[^/]*' /proc/$(pgrep -f 'quickshell -c OozeShell' | head -1)/maps
# Si los dos hashes coinciden, está todo bien.
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = [ pkgs.cmake pkgs.ninja pkgs.pkg-config ];
  buildInputs = [ pkgs.qt6.qtbase pkgs.qt6.qtdeclarative ];
}
