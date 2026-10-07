{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./system.nix
    ./nvidia.nix
    ./desktop.nix
    ./packages.nix
    ./opencode.nix
  ];
}
