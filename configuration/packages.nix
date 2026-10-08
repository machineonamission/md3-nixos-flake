{ config, pkgs, ... }: {
  environment.localBinInPath = true;

  # Minimal system packages (keep only truly needed system-wide tools)
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
  ];

  programs = {
    git.enable = true;
    firefox.enable = true;
    steam.enable = true;
    kdeconnect.enable = true;
  };

}
