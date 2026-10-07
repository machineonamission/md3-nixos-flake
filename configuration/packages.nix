{ config, pkgs, ... }: {
  environment.localBinInPath = true;

  # Minimal system packages (keep only truly needed system-wide tools)
  environment.systemPackages = with pkgs; [
    git
    git-lfs
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
    llama-cpp
  ];

  # Heavy / user-specific packages moved to user profile (home-manager)
  # This prevents them from rebuilding on every nixos-rebuild switch
}
