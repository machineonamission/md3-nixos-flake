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
    # error: Refusing to evaluate package 'gtk+-2.24.33' in /nix/store/x85g4cmcjva68vjxn3wr5j3mabvx0jk4-source/pkgs/by-name/gt/gtk2/package.nix:155 because it has problems:
    #     - broken: gtk2 will be removed because because its final release 2.24.33 happened in December 2020.
    #     Packages using it should be migrated to gtk3 or gtk4 before NixOS 27.05.
    #      (https://github.com/NixOS/nixpkgs/issues/410814)
    problems.handlers = {
      "gtk+".broken = "warn"; # or "ignore"
    };
  };

  # --- Nix settings (substituters + trusted keys) ---
  # These are the full set of cache mirrors and their public keys.
  nix.settings = {
    # --- Speed: download prebuilt binaries instead of compiling ---
    # The substituters below + substitute (default on) make Nix download
    # prebuilt binaries from cache.nixos.org + flox instead of compiling. That
    # is the main "download instead of build" lever and it works on Nix 2.34.9.
    # keep-going: keep building the rest if one derivation fails (e.g. a broken
    # package), instead of aborting the whole switch on the first error.
    keep-going = true;
    # Parallel build jobs. i7-14700K = 28 logical threads (16 P-threads + 8
    # E-cores). 24 jobs ~= 85% CPU — your "~80% vibes budget" so it lags the
    # desktop a bit while building. Want full tilt? set to 28. Want it cooler?
    # lower it. Nix still runs builds at nice/ionice priority 5 by default, so
    # interactive apps (games, GUIs) keep scheduling priority.
    max-jobs = 24;

    experimental-features = [
      "nix-command"
      "flakes"
      # "http-cache"  <- re-enable after upgrading Nix to 2.35+ (unsupported on
      # 2.34.x). Caches downloaded binaries + HTTP build outputs so repeat
      # downloads are served from disk. Content-addressed caches are immutable.
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

  # --- System-wide environment variables ---
  # Exported to every user and the global (PAM) environment on the host.
  environment.variables = {
    MEMINI_HOME = "personal/melody";
  };

  # --- Desktop / GUI session environment variables ---
  # Inherited by GUI apps launched from the desktop (KDE, terminals started from
  # the panel, double-clicked AppImages). SubControl bundles its own libvulkan
  # loader but ships no Vulkan ICD driver, so wgpu can't create a surface
  # ("Failed to create surface for any enabled backend"). Point VK_ICD at the
  # Intel iGPU driver. See modules/portable.nix for the split-package note.
  environment.sessionVariables = {
    VK_ICD_FILENAMES = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";
  };

  # --- Portable apps (nix-ld + run-portable wrapper) ---
  # Fully-featured nix-ld: preload common libs (openssl, icu, fonts, etc.) for
  # every Nix app, plus a `run-portable` wrapper for arbitrary portable apps.
  programs.portableApps.enable = true;

  # Pure Vision — real-time on-device censoring overlay (PuryFi, NVIDIA build).
  # Bundles its own libs; only needs NVML from the driver (added to nix-ld).
  # apps.purevision.enable = true;

  # --- System state version ---
  system.stateVersion = "26.11"; # Updated from "26.05" for NixOS 26.11 compatibility
}
