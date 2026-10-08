# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./modules
  ];

  # --- Nixpkgs configuration ---
  # NOTE: cudaSupport = true is deliberately OMITTED here. Setting it forces
  # rebuild of ALL packages from source (breaks binary cache). The nvidia module
  # and llama-cpp-cuda derive their own CUDA-aware builds via pkgs-llama.
  nixpkgs.config = {
    allowUnfree = true;
    cudaCapabilities = [ "12.0" ];
    nvidia.acceptLicense = true;
  };

  # --- Nix settings (substituters + trusted keys) ---
  # These are the full set of cache mirrors and their public keys.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "melody" "root" ];

    substituters = [
      "https://cache.nixos.org"
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # --- System state version ---
  system.stateVersion = "26.11";  # Updated from "26.05" for NixOS 26.11 compatibility
}
