{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) stdenv;
in
{
  home.username = "melody";
  home.homeDirectory = "/home/melody";
  # User-level packages that were previously in environment.systemPackages
  home.packages = with pkgs; [
    # Dev tools
    android-studio
    arduino-ide
    blockbench
    bs-manager
    bun
    burpsuite
    butane
    cmake
    # Note: cargo, clippy, rustfmt are managed by rustup toolchain — don't list separately (causes path conflicts)
    clang
    clang-tools
    cloc
    ccache
    cloudflare-warp
    dotnet-sdk
    equibop
    ffmpeg
    fnm
    # Note: gdb conflicts with cuda-merged (CUDA includes gdb syscalls)
    gh
    git-lfs
    gnupg
    keepassxc
    ninja
    nodejs
    obs-studio
    obsidian
    pkg-config
    podman
    podman-desktop
    powershell
    prismlauncher
    ripgrep
    rustc
    rustup
    # Note: clippy, cargo-fmt are managed by rustup toolchain — don't list separately (causes path conflicts)
    shotcut
    sqlite
    telegram-desktop
    teams-for-linux
    thunderbird
    tree
    unzip
    uv
    wget

    # Browsers
    chromium
    google-chrome
    microsoft-edge

    # Creative / Design
    fontforge
    inkscape
    krita
    libreoffice
    xournalpp

    # KDE Apps
    kdePackages.kdenlive
    haruna
    kdePackages.kolourpaint
    kdePackages.kamoso
    kdePackages.kclock
    kdePackages.marknote
    kdePackages.kdeconnect-kde
    krename
    kdePackages.filelight
    kdePackages.kio-admin
    posy-cursors
    flameshot

    # Fonts
    atkinson-hyperlegible-next
    atkinson-hyperlegible-mono

    # Wine / Compatibility
    wineWow64Packages.stable
    winetricks
    bottles
    freerdp
    virt-manager

    # HPLIP
    hplip

    # NVIDIA / ML inference (system-level, but handy on user PATH)
    cudatoolkit

    # JetBrains IDEs
    jetbrains.clion
    jetbrains.goland
    jetbrains.idea
    jetbrains.phpstorm
    jetbrains.pycharm
    jetbrains.rider
    jetbrains.rust-rover
    jetbrains.webstorm

    # Games / Entertainment
    discord
    spotify
    zapzap
    lutris

    # Utilities
    qdirstat
    nano
    just
    vulkan-loader
    vulkan-headers
    vulkan-tools

    nixfmt-tree
  ];


  # Enable direnv for the user
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Git config (user-level)
  programs.git = {
    enable = true;
    settings.user.name = "Melody";
    settings.user.email = "machineonamission@gmail.com";
  };

  # SSH agent
  programs.ssh = {
    enable = true;
    settings."*".AddKeysToAgent = "yes";
  };

  # Shell preferences
  programs.bash = {
    enable = true;
    historySize = 100000000;
    historyControl = [
      "ignoredups"
      "erasedups"
    ];
  };

  # Home-manager version
  home.stateVersion = "26.11";
}
