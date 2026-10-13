{ lib, ... }: {
  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    ./services.nix
    ./packages.nix
    ./desktop.nix
    ./opencode.nix
    ./llama.nix
    ./portable.nix
    #./llama-presets.nix
  ];
}
