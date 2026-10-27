{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # OpenCode CLI + Desktop GUI from pinned v2.2.0 flake input.
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
  #
  # opencode 2.2.0 flake bug fix: packages/desktop/script/build.ts hardcodes the
  # bundled CLI path to ../cli/dist and ignores OPENCODE_CLI_DIST, so the Nix prod
  # build (which stages the CLI at $TMPDIR/desktop-cli per nix/desktop.nix) trips
  # the prod guard. preBuild below rewrites that path to honor OPENCODE_CLI_DIST.
  environment.systemPackages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
      /*
        .overrideAttrs (_old: {
          # opencode 2.2.0's packages/desktop/script/build.ts hardcodes the bundled CLI
          # path to ../cli/dist and IGNORES OPENCODE_CLI_DIST. The Nix flake
          # (nix/desktop.nix) stages the CLI at $TMPDIR/desktop-cli, so the prod guard
          # trips: "Production desktop builds bundle the CLI from .../packages/cli/dist;
          # build it first". Honor the env var the flake already sets. Upstream later
          # fixed this by switching build.ts to read OPENCODE_CLI_DIST (prebuild.ts).
          #
          # NOTE: use postPatch (a post* hook), not preBuild. stdenv's overrideAttrs
          # reliably keeps post* hooks but drops a lone preBuild override, so the
          # substitution below would silently never run.
          postPatch = ''
            ${_old.postPatch or ""}
            substituteInPlace packages/desktop/script/build.ts \
              --replace-fail 'const cli = path.resolve(dir, "../cli/dist")' \
              'const cli = process.env.OPENCODE_CLI_DIST || path.resolve(dir, "../cli/dist")'
          '';

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
        })
      */
    )
  ];
}
