# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  home-manager,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./configuration
    # Home-manager for user-level packages (replaces the old 70+ system packages)
#    home-manager.nixosModules.home-manager
  ];

  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaCapabilities = [ "12.1" ]; # RTX 5070 Ti (GB202 Blackwell)
    cudaForwardCompat = true;
    cudaSupport = true;
  };
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "melody"
      "root"
    ];
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

}
