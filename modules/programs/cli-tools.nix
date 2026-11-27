# System-wide command-line tools (all modes).
{ pkgs, ... }:
{
  environment.localBinInPath = true;

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

    openssl.dev
    pkg-config
    android-tools

    unrar
    p7zip
    rar
  ];
}
