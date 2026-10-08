{ config, pkgs, lib, inputs, ... }: {
  # OpenCode CLI + Desktop GUI from pinned v2.0.24 flake input.
  #
  # WHY PINNED: nixos-unstable has a bun version mismatch bug
  # (package.json requires bun 1.3.9, unstable provides 1.3.8).
  # This causes opencode-desktop build failures on fresh builds.
  # See: https://github.com/anomalyco/opencode/issues/13291
  #
  # When updating to a newer version, verify the bun dependency is satisfied
  # in nixos-unstable before building opencode-desktop.
  environment.systemPackages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
  ];
}
