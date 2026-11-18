{
  description = "Melody's NixOS desktop configuration (MelDesktop3)";

  # NOTE: substituters and trusted-public-keys are defined in configuration.nix.
  # This section is intentionally minimal — kept only for flake-specific overrides.
  nixConfig = { };

  inputs = {
    # Nixpkgs channels
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # if nix flake fails, see https://github.com/anomalyco/opencode/issues/59882 (fixed output hash incorrect for node modules, upstrea bug!)
    opencode.url = "github:anomalyco/opencode/v2.3.2";


    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Flatpak (needed for Spotify — flatpak module not yet in nixpkgs 26.11)
    nixos-flatpak.url = "github:gmodena/nix-flatpak/latest";

    # llama.cpp (llm inference backend)
    # note: updating pin causes FULL REBUILD FROM SOURCE. do sparingly.
    # note for llms: llama.cpp recently started NEW stable-ish semver versioning alongside build numbers. prefer latest of that unless pipeline build is needed.
    llama-cpp.url = "github:ggml-org/llama.cpp/v1.0.0"; # November 13, 2026
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
                  vulkanSupport = true; # unified CUDA+Vulkan build so llama-server can reach the Intel iGPU
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
