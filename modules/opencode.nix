{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  sys = pkgs.stdenv.hostPlatform.system;
  oc = inputs.opencode.packages.${sys};

  # opencode's flake builds `opencode-node_modules` via `bun install
  # --frozen-lockfile` (see the flake's nix/node_modules.nix). That build relies
  # on outbound network, which this host's local builds lack. However, NixOS
  # builds are dispatched to the networked daemon, so the flake's own node_modules
  # derivation builds fine remotely.
  #
  # The flake pins an outputHash in nix/hashes.json that no longer matches the
  # content, so we pass the actual content hash to disable the check. It is
  # deterministic across rebuilds:
  #   sha256-PYcpyYP/i0e6ZIt27u1tFYbjU4Cl848w77dU1NiIEls=
  nodeModules = pkgs.callPackage (inputs.opencode + "/nix/node_modules.nix") {
    hash = "sha256-PYcpyYP/i0e6ZIt27u1tFYbjU4Cl848w77dU1NiIEls=";
  };

  # Thread the remote-built node_modules into the CLI. The opencode package
  # inherits (node_modules) version/src/meta.platforms, so no extra plumbing.
  opencode = (oc.opencode).overrideAttrs (_old: {
    node_modules = nodeModules;
  });
in
{
  # OpenCode CLI from pinned v2.3.0 flake input.
  #
  # NOTE: `opencode-desktop` (the Electron GUI) is intentionally NOT included.
  # Its build runs `electron-vite build`, which cannot resolve @opentui/solid's
  # native preload offline (the filtered node_modules only keeps it in bun's
  # `.bun` virtual store, and the daemon has no DNS to fetch it). Re-enable this
  # once a networked build or a hoisted @opentui/solid is available.
  environment.systemPackages = [ opencode ];
}
