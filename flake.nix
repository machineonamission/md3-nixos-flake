{
  inputs = {
    # Using nixos-unstable (26.11) as the base channel
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

    opencode.url = "github:anomalyco/opencode/v2.0.24";
    opencode.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      # NOTE: 'nixos' is the default hostname
      nixConfig = {
        extra-trusted-substituters = [
          "https://cache.nixos-cuda.org"
          "https://cache.flox.dev"
        ];
        extra-trusted-public-keys = [
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
        ];
      };
      nixosConfigurations."MelDesktop3" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
        specialArgs = { inherit inputs home-manager; };
      };

      # Home-manager configuration for user 'melody'
      homeConfigurations.melody = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/melody.nix
        ];
      };
    };
}
