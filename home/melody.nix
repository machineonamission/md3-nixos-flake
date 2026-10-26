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
  # note, m2 may have hallucinated packageS plural?
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
    rclone
    vulkan-loader
    vulkan-headers
    vulkan-tools

    nixfmt-tree

    vscode

    # Backup for weird dev stuff that needs the FHS sandbox (native ext binaries).
    # Renamed so its desktop entry + URL-handler scheme don't collide with `vscode`.
    /*
      (vscode-fhs.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          # $out/share is a symlink into the read-only store, so replace it with a
          # writable copy before renaming the fhs desktop entries. This avoids
          # colliding with the primary `vscode` package, which shares
          # executableName="code" and the x-scheme-handler/vscode URL scheme.
          if [ -L "$out/share" ]; then
            __fhs_share=$(readlink "$out/share")
            rm -f "$out/share"
            cp -aL "$__fhs_share" "$out/share"
          fi

          if [ -e "$out/share/applications/code.desktop" ]; then
            mv "$out/share/applications/code.desktop" "$out/share/applications/code-fhs.desktop"
            sed -i 's#^Name=Visual Studio Code$#Name=Visual Studio Code (FHS)#' "$out/share/applications/code-fhs.desktop"
          fi
          if [ -e "$out/share/applications/code-url-handler.desktop" ]; then
            mv "$out/share/applications/code-url-handler.desktop" "$out/share/applications/code-fhs-url-handler.desktop"
            sed -i \
              -e 's#^MimeType=x-scheme-handler/vscode$#MimeType=x-scheme-handler/vscode-fhs#' \
              -e 's#^Name=Visual Studio Code - URL Handler$#Name=Visual Studio Code (FHS) - URL Handler#' \
              "$out/share/applications/code-fhs-url-handler.desktop"
          fi
        '';
      }))
    */

    python314Packages.huggingface-hub

    systemdgenie
    godot
    kdePackages.kjournald

    shellcheck

    # flatpak tooling (artemis lmao)
    flatpak
    flatpak-builder
    flatpak-xdg-utils
    yq

    # nix tooling
    nixfmt
    nixd
    nil
    statix
    alejandra

    kdePackages.kfind

    pnpm

    qbittorrent
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

  # rclone + SLU OneDrive WebDAV mount
  home.file."config/rclone/rclone.conf".text = ''
    [slu-onedrive]
    type = webdav
    url = https://slu-my.sharepoint.com/personal/melody_neimeyer_slu_edu/Documents
    vendor = sharepoint
    user = melody.neimeyer@slu.edu
    pass = ENC:PLACEHOLDER_FILL_WITH_RCLONE_CONFIG_OUTPUT
  '';

  systemd.user.services.rclone-slu-onedrive = {
    Unit.Description = "SLU OneDrive WebDAV mount via rclone";
    Install.WantedBy = [ "default.target" ];
    Service.Type = "notify";
    Service.ExecStart = "${pkgs.rclone}/bin/rclone mount slu-onedrive:/ /home/melody/slu-onedrive --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 1h --log-level INFO --log-file /tmp/rclone-slu.log";
    Service.Restart = "on-failure";
    Service.RestartSec = 5;
  };

  #  services.home-manager.autoUpgrade.enable = true;
  fonts.fontconfig.enable = true;

  # Home-manager version
  home.stateVersion = "26.05";
}
