# Nix daemon + nixpkgs settings.
{
  nixpkgs.config = {
    allowUnfree = true;
    cudaCapabilities = [ "12.0" ];
    nvidia.acceptLicense = true;
    # Deliberately NO cudaSupport here: it would rebuild every CUDA-capable
    # package from source. llama.cpp gets CUDA via pkgs-llama (flake.nix), built
    # from the `llama-cpp` flake input (master; modules/llm/llama-swap/helpers.nix).
    #
    # gtk2 (final release 2020) is marked broken ahead of its removal in 27.05;
    # downgrade that to a warning until the apps still using it migrate.
    problems.handlers."gtk+".broken = "warn";
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
    # i7-14700K = 28 threads; 24 jobs ≈ 85 % CPU. Builds run at nice 5, so the
    # desktop stays responsive.
    max-jobs = 24;
    keep-going = true; # one broken derivation doesn't abort the rest
    auto-optimise-store = true;

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

  # Periodic `nix-store --optimise` (see https://wiki.nixos.org/wiki/Storage_optimization)
  nix.optimise.automatic = true;
}
