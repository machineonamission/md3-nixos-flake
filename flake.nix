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
    opencode.url = "github:anomalyco/opencode/v2.4.1";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";

    # Flatpak (needed for Spotify — flatpak module not yet in nixpkgs 26.11)
    nixos-flatpak.url = "github:gmodena/nix-flatpak/latest";

    # llama.cpp (llm inference backend)
    # note: updating pin causes FULL REBUILD FROM SOURCE. do sparingly.
    # note for llms: llama.cpp recently started NEW stable-ish semver versioning alongside build numbers. prefer latest of that unless pipeline build is needed.
    llama-cpp.url = "github:ggml-org/llama.cpp/v1.0.0"; # November 13, 2026
    # new note: removing nixpkgs follows might cause version bumps to pull from caches instead of happening all the time? so lol
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
    let
      system = "x86_64-linux";

      # CUDA-aware pkgs for llama-cpp (separate from main pkgs to avoid cache
      # busting). Computed ONCE here and threaded into every boot mode via
      # specialArgs, so all three systems share the same derivation.
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

      # ---------------------------------------------------------------------
      # makeSystem — build one NixOS system for a given GPU/desktop mode.
      #
      # All three boot entries share the SAME configuration.nix + home-manager +
      # flatpak setup. The ONLY thing that differs is which mode-specific modules
      # are imported, and that is decided HERE by branching on `mode` — a plain
      # Nix variable, NOT `config`. Branching on `config` (the recursive merged
      # config) is what causes infinite recursion; branching on a plain variable
      # is safe and is the idiomatic way to do multi-config flakes.
      #
      #   normal   — full desktop, dGPU drives displays, iGPU for Vulkan LLM
      #              title models. The current production config.
      #   saver    — same desktop, but every GUI app renders on the iGPU by
      #              default (GALLIUM_DRIVER=iris system-wide), freeing dGPU
      #              VRAM for llama-swap. Monitors stay on the dGPU at full
      #              res/refresh/HDR.
      #   headless — no display manager, no desktop, no Xorg. Just a raw TTY on
      #              the monitors (dGPU modesetting framebuffer, ~2 MB VRAM).
      #              The dGPU is free for CUDA compute.
      #
      # The shared modules (user, hardware, networking, services, packages,
      # llama, etc.) live in ./modules and are imported unconditionally via
      # configuration.nix. Only the mode-specific modules below are branched.
      # ---------------------------------------------------------------------
      makeSystem =
        mode:
        nixpkgs-unstable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            inherit pkgs-llama;
          };
          modules = [
            ./configuration.nix
            # Distinct boot-menu label per mode. system.name defaults to
            # networking.hostName ("MelDesktop3") in every mode, which would make
            # all three systemd-boot entries look identical and impossible to tell
            # apart at boot. Setting it per mode (branched on the plain `mode`
            # variable, so no recursion) gives each a unique, human-readable
            # label in the boot menu and a distinct system path in the store.
            # Plain set (NOT a function): `system.name` is a pure option
            # declaration. Wrapping it in `({ system }: …)` would destructure
            # the module's special-args and shadow the `system` option
            # namespace, breaking evaluation.
            {
              system.name =
                if mode == "saver" then
                  "MelDesktop3-saver"
                else if mode == "headless" then
                  "MelDesktop3-headless"
                else
                  "MelDesktop3";
            }
          ]
          # Mode-specific modules. Branched on `mode` (a plain variable), so no
          # recursion. Headless gets the raw-TTY console; normal/saver get the
          # desktop stack + the per-app run-on-igpu wrapper; saver additionally
          # gets the system-wide iGPU env vars.
          ++ (
            if mode == "headless" then
              [ ./modules/headless.nix ]
            else
              [
                ./modules/desktop.nix
                ./modules/gpu-offload.nix
              ]
              ++ (if mode == "saver" then [ ./modules/saver.nix ] else [ ])
          )
          # Flatpak system module — desktop-only. Headless mode has no flatpak
          # (no desktop to run flatpak apps), so the whole flatpak stack is
          # skipped there. Branched on `mode`, so no recursion.
          ++ (if mode != "headless" then [ (import "${nixos-flatpak}/modules/nixos.nix") ] else [ ])
          # Home Manager — the user's home config is shared across all modes
          # (identical in normal / saver / headless), but the flatpak shared
          # module is desktop-only. Branched on `mode`, so no recursion.
          ++ [
            home-manager.nixosModules.home-manager
            {
              home-manager.sharedModules = (
                if mode != "headless" then [ (import "${nixos-flatpak}/modules/home-manager.nix") ] else [ ]
              );
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.melody = {
                imports = [
                  (import ./home/melody.nix)
                ]
                # The Spotify flatpak package (home/spotify.nix) is desktop-only.
                # In headless mode the flatpak home module is not imported, so it
                # is skipped. Branched on `mode`, so no recursion.
                ++ (if mode != "headless" then [ (import ./home/spotify.nix) ] else [ ]);
              };
              home-manager.extraSpecialArgs = { inherit inputs; };

              # Nix settings for maximum caching + disk optimization
              nix.settings.auto-optimise-store = true;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # Normal desktop — dGPU drives displays, iGPU for Vulkan LLM title models.
        # This is the current production config.
        MelDesktop3 = makeSystem "normal";

        # Extreme GPU VRAM saver — same desktop, but every GUI app renders on the
        # iGPU by default (GALLIUM_DRIVER=iris system-wide), freeing dGPU VRAM for
        # llama-swap. Monitors stay on the dGPU at full res/refresh/HDR.
        MelDesktop3-saver = makeSystem "saver";

        # Headless — no display manager, no desktop, no Xorg. Just a raw TTY on
        # the monitors (dGPU modesetting framebuffer, ~2 MB VRAM). The dGPU is
        # free for CUDA compute. For remote / SSH use when you want the full
        # 16 GB for the model.
        MelDesktop3-headless = makeSystem "headless";
      };
    };
}
