{
  description = "Melody's NixOS desktop configuration (MelDesktop3)";

  # NOTE: substituters and trusted-public-keys are defined in configuration.nix.
  # This section is intentionally minimal — kept only for flake-specific overrides.
  nixConfig = { };

  inputs = {
    # Nixpkgs channels
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # OpenCode v2 (pinned to v2.0.24 to avoid bun version bump bug on unstable)
    opencode.url = "github:anomalyco/opencode/v2.0.24";
    opencode.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Flatpak (needed for Spotify — flatpak module not yet in nixpkgs 26.11)
    nixos-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";

    # LLaMA C++ (CUDA build from source)
    llama-cpp.url = "github:ggml-org/llama.cpp/v0.6.0";
    llama-cpp.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs =
    inputs@{
      self,
      nixpkgs-stable,
      nixpkgs-unstable,
      home-manager,
      nixos-flatpak,
      ...
    }:
    {
      nixosConfigurations = {
        MelDesktop3 = nixpkgs-unstable.lib.nixosSystem {
          specialArgs =
            let
              system = "x86_64-linux";
            in
            {
              inherit inputs;

              # CUDA-aware pkgs for llama-cpp (separate from main pkgs to avoid cache busting)
              # NOTE: The deprecation warning "'system' has been renamed to/replaced by
              # 'stdenv.hostPlatform.system'" is a false positive for flakes — `${system}`
              # here comes from flake inputs (idiomatic). We use `import` with config to
              # allow unfree CUDA packages needed for llama-cpp-cuda build.
              pkgs-llama = import inputs.nixpkgs-unstable {
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
            (import "${nixos-flatpak}/modules/nixos.nix")
            {
              home-manager.sharedModules = [ (import "${nixos-flatpak}/modules/home-manager.nix") ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.melody = import ./home/melody.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };

              # Nix settings for maximum caching + disk optimization
              nix.settings.auto-optimise-store = true;
            }
          ];
        };
      };
    };
}
