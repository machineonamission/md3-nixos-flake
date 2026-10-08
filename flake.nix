{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    opencode.url = "github:anomalyco/opencode/v2.0.24";
    opencode.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    llama-cpp.url = "github:ggml-org/llama.cpp/v0.6.0";
    llama-cpp.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }:
    {
      # NOTE: 'nixos' is the default hostname
      nixosConfigurations = {
        MelDesktop3 = nixpkgs-unstable.lib.nixosSystem {
          specialArgs =
            let
              system = "x86_64-linux";
            in
            {
              inherit inputs;
#              pkgs = import nixpkgs {
#                inherit system;
#                config.allowUnfree = true;
#              };
              pkgs-llama = import nixpkgs-unstable {
                inherit system;
                config = {
                  allowUnfree = true;
                  cudaSupport = true;
                  cudaCapabilities = [ "12.0" ];
                  nvidia.acceptLicense = true;
                };
              };
            };
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.melody = import ./home/melody.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };
    };
}
