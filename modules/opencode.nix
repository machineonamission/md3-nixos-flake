{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # OpenCode CLI + Desktop GUI from pinned v2.0.24 flake input.
  #
  # WHY PINNED: nixos-unstable has a bun version mismatch bug
  # (package.json requires bun 1.3.9, unstable provides 1.3.8).
  # This causes opencode-desktop build failures on fresh builds.
  # See: https://github.com/anomalyco/opencode/issues/13291
  #
  # When updating to a newer version, verify the bun dependency is satisfied
  # in nixos-unstable before building opencode-desktop.
  #
  # NVIDIA + Wayland Vulkan bug fix: the Electron launcher uses
  # `--ozone-platform-hint=auto` which crashes on NVIDIA+Wayland.
  # This override forces `--ozone-platform=x11` to avoid the crash.
  environment.systemPackages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop.overrideAttrs (_old: {
      postInstall = ''
        # Fix NVIDIA+Wayland Vulkan crash by forcing X11 ozone platform
        wrapProgram "$out/bin/opencode-desktop" \
          --add-flags "--ozone-platform=x11"

        # Fix desktop freeze on open: the upstream build script creates the bundled CLI
        # in a temp dir ($TMPDIR/desktop-cli) but never copies it into resources/.
        # The desktop app's `desktop-cli.ts` spawns this binary for version detection;
        # without it, `parseCliVersion("")` throws and the startup pipeline hangs.
        mkdir -p "$out/opt/opencode-desktop/resources"
        cp ${lib.getExe inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode} \
          "$out/opt/opencode-desktop/resources/opencode-cli"
      '';
    }))
  ];
}
