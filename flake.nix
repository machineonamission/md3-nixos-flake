{
  description = "Melody's NixOS desktop configuration (MelDesktop3)";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Declarative flatpaks (Spotify: pkgs.spotify was removed in 26.11).
    nixos-flatpak.url = "github:gmodena/nix-flatpak/latest";
    # llama.cpp from source, tracking master (nixpkgs lags weeks behind new model
    # architectures). Built with upstream's own .devops/nix expression on pkgs-llama
    # (modules/llm/llama-swap/helpers.nix). Bump: `nix flake update llama-cpp`
    # (full CUDA rebuild). Not a flake input on purpose: its flake pulls flake-parts
    # and its own nixpkgs, and we only need the source tree.
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs-unstable,
      home-manager,
      nixos-flatpak,
      ...
    }:
    {
      # One system; the saver / headless boot modes are specialisations of it
      # (modules/modes/specialisations.nix), so a single `nixos-rebuild` builds all three.
      nixosConfigurations.MelDesktop3 = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          # Separate CUDA-enabled package set, so cudaSupport doesn't change (and
          # un-cache) every other package. Only the llama module uses it.
          pkgs-llama = import nixpkgs-unstable {
            system = "x86_64-linux";
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
          nixos-flatpak.nixosModules.nix-flatpak
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # nix-flatpak's HM module follows the system's services.flatpak.enable,
              # so it is a no-op in headless mode.
              sharedModules = [ nixos-flatpak.homeManagerModules.nix-flatpak ];
              users.melody.imports = [
                ./home/melody.nix
                ./home/spotify.nix
              ];
            };
          }
        ];
      };
    };
}
