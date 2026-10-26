{
  config,
  pkgs,
  lib,
  ...
}:
let
  # ---------------------------------------------------------------------------
  # Comprehensive library set for portable / non-Nix apps.
  #
  # Portable apps (AppImages, .NET apps, browsers, Steam games, etc.) were built
  # against a standard distro and expect to find common shared libraries on a
  # traditional library search path. NixOS keeps every library isolated in the
  # store, so these apps fail with "error while loading shared libraries".
  #
  # Two mechanisms cover both families of portable apps:
  #
  #   * nix-ld (`programs.nix-ld.libraries`): AppImages and other ELF binaries
  #     link against the Nix dynamic linker and read NIX_LD_LIBRARY_PATH, so a
  #     comprehensive nix-ld set makes them find their system libs globally.
  #
  #   * run-portable (`portableLibs` + LD_LIBRARY_PATH): a wrapper for apps that
  #     are launched outside the nix-ld runtime (e.g. double-clicked AppImages).
  #
  # This list is intentionally broad on purpose — it is cheap to preload and
  # covers the X11 / OpenGL / Wayland / Vulkan / audio / font / crypto /
  # compression stack that desktop apps commonly link.
  #
  # NOTE: package names are matched to THIS nixpkgs checkout. If you bump nixpkgs
  # and a build fails on an unknown attribute, rename it (e.g. `libsoup` ->
  # `libsoup_3`, `freetype2` -> `freetype`, `mesa-libgbm` -> `libgbm`).
  # ---------------------------------------------------------------------------
  nixLdLibraries = with pkgs; [
    # compression
    zlib
    zstd
    xz
    bzip2
    lz4
    libarchive
    # C / C++ runtime
    stdenv.cc.cc
    # crypto / TLS
    openssl
    libssh
    libsodium
    libgcrypt
    libgpg-error
    p11-kit
    nettle
    gnutls
    krb5
    libidn2
    # system / utilities
    util-linux
    acl
    attr
    libcap
    systemd
    curl
    libxml2
    # fonts / text shaping
    freetype
    fontconfig
    harfbuzz
    fribidi
    libxkbcommon
    # audio
    alsa-lib
    pipewire
    pulseaudio
    libsndfile
    # graphics / GPU (mesa split libgbm into its own package here)
    mesa
    libgbm
    libdrm
    libglvnd
    # Vulkan *loader* (libvulkan.so.1). The ICD drivers (mesa, nvidia) are above;
    # the loader itself is a separate package that portable apps dlopen at runtime.
    # - (AppImage) needs it or its overlay/renderer dies with
    # "Vulkan loader error: libvulkan.so.1: cannot open shared object file".
    vulkan-loader
    # X11
    libX11
    libxcb
    libXext
    libXrender
    libXcursor
    libXrandr
    libXi
    libXinerama
    libXfixes
    libXdamage
    libXcomposite
    libXt
    libice
    libsm
    # Wayland
    wayland
    wayland-protocols
    # GTK / GLib stack
    glib
    gdk-pixbuf
    pango
    cairo
    atk
    libsoup_3
    libepoxy
    libthai
    libdatrie
    # image
    libpng
    lcms2
    libexif
    # misc
    icu
    libffi
    expat
  ];

  # Extra GUI libraries that some desktop apps link but that are less common.
  # (libxcb-render/libxcb-shm/libxkbcommon-x11/libxkbregistry are bundled inside
  #  libxcb / libxkbcommon, which are already listed above.)
  guiLibraries = with pkgs; [
    libXmu
    libXpm
  ];

  # Full set for GUI portable apps: everything above plus the X11 / OpenGL /
  # Wayland / Vulkan stack that desktop apps (Artemis, Steam games, etc.) link.
  portableLibraries =
    with pkgs;
    nixLdLibraries
    ++ guiLibraries
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
    pathsToLink = [ "/lib" ];
    paths = map (p: lib.getLib p) portableLibraries;
    ignoreCollisions = true;
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
    Enable nix-ld with a comprehensive library set and the run-portable wrapper.
  '';

  config = lib.mkIf config.programs.portableApps.enable {
    # --- Comprehensive nix-ld ---
    # Preload the full library set for every Nix app so AppImages and other
    # portable ELF binaries find their system libs globally via NIX_LD_LIBRARY_PATH.
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = nixLdLibraries;

    # Wrapper for arbitrary portable apps: run-portable /path/to/binary
    environment.systemPackages = [ runPortable ];
  };
}
