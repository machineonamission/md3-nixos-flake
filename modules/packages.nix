{ config, pkgs, lib, ... }: {
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
}
