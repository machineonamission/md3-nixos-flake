{
  description = "Melody's NixOS desktop configuration (MelDesktop3)";

  # NOTE: substituters and trusted-public-keys are defined in configuration.nix.
  # This section is intentionally minimal — kept only for flake-specific overrides.
  nixConfig = { };

  inputs = {
    # Nixpkgs channels
    # TEMP PIN (2026-10-21): roll nixpkgs-unstable back to fe13242281, where glibc is
    # 2.44-25 and nvidia-smi works (rc=0). The current tip 02c087f bumped glibc to
    # 2.44-57, which segfaults nvidia-smi (rc=139) on MelDesktop3. Revert this url to
    # "github:NixOS/nixpkgs/nixos-unstable" and run `nix flake update nixpkgs-unstable`
    # once upstream fixes glibc.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # OpenCode v2
    opencode.url = "github:anomalyco/opencode/v2.1.1";
    opencode.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Flatpak (needed for Spotify — flatpak module not yet in nixpkgs 26.11)
    nixos-flatpak.url = "github:gmodena/nix-flatpak/latest";

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
