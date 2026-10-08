{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.username = "melody";
  home.homeDirectory = "/home/melody";

  # Spotify via flatpak (pkgs.spotify removed from nixpkgs 26.11)
  services.flatpak.enable = true;
  services.flatpak.packages = [
    {
      appId = "com.spotify.Client";
      origin = "flathub";
    }
  ];

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
    gnupg
    keepassxc
    ninja
    nodejs
    #    obs-studio
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

    vscode
  ];

  programs.home-manager.enable = true;
  programs.direnv.enable = true;
  programs.git = {
    settings.user.name = "Melody";
    settings.user.email = "machineonamission@gmail.com";
  };
  programs.bash = {
    enable = true;
    historySize = 100000000;
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  # SSH config (raw file — avoids conflict with NixOS programs.ssh module)
  home.file.".ssh/config".text = ''
    Host *
      ForwardAgent no
      AddKeysToAgent yes
      Compression no
      ServerAliveInterval 0
      ServerAliveCountMax 3
      HashKnownHosts no
      ControlMaster auto
      ControlPath ~/.ssh/master-%r@%n:%p
  '';

#  services.home-manager.autoUpgrade.enable = true;
  fonts.fontconfig.enable = true;

  # Home-manager version
  home.stateVersion = "26.05";
}
