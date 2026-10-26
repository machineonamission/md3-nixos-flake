{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.localBinInPath = true;

  # Minimal system packages (truly needed system-wide tools)
  environment.systemPackages = with pkgs; [
    jq
    curl
    wget
    unzip
    tree
    ripgrep
    fd
    nixfmt
    ccache
    gnupg
    atkinson-hyperlegible-next
    atkinson-hyperlegible-mono
    noto-fonts

    openssl.dev
    pkg-config
    android-tools

    kdePackages.xdg-desktop-portal-kde

    # FHS-compatible runner for weird apps nix-ld can't handle alone
    # (apps that hardcode /usr/lib paths, bundle their own loader, or need a
    # traditional library layout). `bwrap` sets up a bind-mount FHS sandbox.
    bubblewrap

    # AppImages that shell out to KDE/glib CLI tools (- needs `gdbus`
    # + `kwriteconfig6` for its KWin "effects" feature). kwriteconfig6 ships in
    # the base system; gdbus lives in glib's -bin output.
    glib
    appimage-run
  ];

  # Programs: git + other system programs
  programs.git = {
    enable = true;
    config = {
      user.name = "Melody";
      user.email = "machineonamission@gmail.com";
    };
  };
  # M2 identity — available to root for committing/pushing to GitHub org
  environment.etc."git-m2.conf".text = ''
    [user]
      name = M2
      email = m2@machineonamission.com
  '';

  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.kdeconnect.enable = true;

  #programs.adb.enable = true;
  users.users.melody.extraGroups = [ "adbusers" ];
}
