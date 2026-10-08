{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./system.nix
    ./nvidia.nix
    ./desktop.nix
    ./packages.nix
    ./opencode.nix
    ./llama.nix
  ];
}
