# SECCION: PACKAGE NIXOS
# IPC: build install
{
  lib,
  rustPlatform,
  pkg-config,
  mpvpaper,
  mpv,
  ffmpeg,
  socat,
  matugen,
  fontconfig,
  freetype,
  libGL,
  wayland,
  libxkbcommon,
  libX11,
  libXcursor,
  libXrandr,
  libXi,
  makeWrapper,
}:
rustPlatform.buildRustPackage {
  pname = "oozewalls";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [
    mpvpaper
    mpv
    ffmpeg
    socat
    matugen
    fontconfig
    freetype
    libGL
    wayland
    libxkbcommon
    libX11
    libXcursor
    libXrandr
    libXi
  ];
  postInstall = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/scalable/apps
    cp $src/oozewalls-gui.desktop $out/share/applications/
    cp $src/oozewalls.svg $out/share/icons/hicolor/scalable/apps/oozewalls.svg
    wrapProgram $out/bin/oozewalls-gui \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL wayland libxkbcommon libX11 libXcursor libXrandr libXi fontconfig freetype ]} \
      --suffix PATH : ${lib.makeBinPath [ mpvpaper mpv ffmpeg socat matugen ]}
  '';
  meta = with lib; {
    description = "Motor minimo de wallpapers via mpvpaper controlable desde Quickshell";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "oozewalls-gui";
  };
}
