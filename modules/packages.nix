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
  ];

  # TODO: 2nd git identity? is this possible?
  programs.git.enable = true;
  programs.git.config = {
    user.name = "Melody";
    user.email = "machineonamission@gmail.com";
  };

  # Other system-wide programs
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.kdeconnect.enable = true;
}
