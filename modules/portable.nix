{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Core system libraries that portable (non-Nix) apps expect to find on a
  # standard Linux distro but that NixOS keeps isolated in the store.
  #
  # These are low-risk to preload globally AND cover the bulk of portable-app
  # failures — the "openssl" pain point, unicode/globalization (.NET, browsers),
  # fonts, and compression. Preloaded for every Nix app via nix-ld.
  nixLdLibraries = with pkgs; [
    zlib
    zstd
    stdenv.cc.cc
    curl
    openssl
    attr
    libssh
    bzip2
    libxml2
    acl
    libsodium
    util-linux
    xz
    systemd
    icu
    fontconfig
    freetype
    libpng
    fribidi
    libunibreak
    lz4
    alsa-lib
    pipewire
    harfbuzz
  ];

  # Full set for GUI portable apps: everything above plus the X11 / OpenGL /
  # Wayland / Vulkan stack that desktop apps (Artemis, Steam games, etc.) link.
  portableLibraries =
    with pkgs;
    nixLdLibraries
    ++ [
      libx11
      libxext
      libxrender
      libxcursor
      libxrandr
      libxi
      libxcb
      libxkbcommon
      libice
      libsm
      mesa
      wayland
      vulkan-loader
    ];

  # One store path holding the 64-bit libs portable apps need.
  portableLibs = pkgs.buildEnv {
    name = "portable-compat-libs";
    paths = map (p: lib.getLib p) portableLibraries;
  };

  # Run a portable / non-Nix app with the system library set preloaded.
  # Portable apps often expect to run from their own directory (e.g. .NET apps
  # locate their .dll next to the binary, flatpak-style layouts expect CWD),
  # so we cd into the app's folder before exec.
  runPortable = pkgs.writeShellScriptBin "run-portable" ''
    #!/bin/bash
    # Usage: run-portable /path/to/app [args...]
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: run-portable <app-path> [args...]" >&2
      exit 1
    fi
    app="$1"; shift
    app_dir="$(cd "$(dirname "$app")" && pwd)"
    export LD_LIBRARY_PATH="${portableLibs}/lib:$LD_LIBRARY_PATH"
    cd "$app_dir"
    exec "$app" "$@"
  '';
in
{
  options.programs.portableApps.enable = lib.mkEnableOption ''
    Enable nix-ld with an expanded library set and the run-portable wrapper.
  '';

  config = lib.mkIf config.programs.portableApps.enable {
    # --- Fully-featured nix-ld ---
    # Preload the common libs for every Nix app so they just work without
    # per-app LD_LIBRARY_PATH fiddling (this fixes the "openssl" pain point
    # at the system level).
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = nixLdLibraries;

    # Wrapper for arbitrary portable apps: run-portable /path/to/binary
    environment.systemPackages = [ runPortable ];
  };
}
