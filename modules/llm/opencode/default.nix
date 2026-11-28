# opencode — packages + the generated ~/.config/opencode/opencode.json.
#
# The whole generated config lives in ./hm-module.nix, shared verbatim with
# the tablet (Arch, standalone home-manager) — see that file's header. This
# file is only the desktop's NixOS side: the packages (from upstream's flake)
# + the `opencode serve` user service.
#
#   settings.nix    — the config as a Nix value (agents, plugins, mcp, ...)
#   providers.nix   — providers; llama-swap models generated from modules/llm/models
#   permissions.nix — global rules + the M2 agents
#   dcp.nix         — the generated ~/.config/opencode/dcp.jsonc (DCP plugin)
#
# Same idea as services.llama-swap.settings: home-manager's programs.opencode
# serializes `settings` to opencode.json (a read-only symlink into the store)
# and, with validateFiles.config, checks it against the package's own v2
# config schema at build time, so a bad key fails `nixos-rebuild build`.
#
# Don't keep an opencode.jsonc next to it: OpenCode prefers it over
# opencode.json, and the generated file would silently lose.
#
# Secrets live in ${secrets} (outside git, chmod 600), one value per file
# with no trailing newline, referenced as {file:...} (see settings.nix):
#   home-assistant-token   HA long-lived access token
#   ha-mcp-url             full HA MCP webhook URL
# A missing file silently becomes "" (that MCP server then just fails to auth).
#
# Check what OpenCode actually loaded (the background service caches config,
# so use a private server):  opencode debug config --standalone
{ lib, pkgs, inputs, ... }:
let
  # Upstream's flake (flake.nix input `opencode`), not nixpkgs, which lags
  # several releases. Bump: change the tag in flake.nix, `nix flake update opencode`.
  opencodePkgs = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system};

  # Workaround 1: upstream's node_modules FOD hash (nix/hashes.json) is wrong for
  # what Bun actually fetches (anomalyco/opencode#59882), so pin the real one.
  # On a tag bump the build fails with "hash mismatch ... got: sha256-..." —
  # paste that here (or set it back to upstream's if they fixed it).
  node_modules = opencodePkgs.opencode.node_modules.override {
    hash = "sha256-RXrwbOwbYAHuofiv5pgvXCmXlbNhOCrvLmDOT8FjiNs=";
  };

  # Workaround 2: upstream doesn't ship the config JSON schema, which
  # home-manager's programs.opencode.validateFiles.config needs as
  # passthru.jsonschema.config. Generated the same way nixpkgs does.
  opencode =
    (opencodePkgs.opencode.override { inherit node_modules; }).overrideAttrs
      (finalAttrs: old: {
        postBuild = (old.postBuild or "") + ''
          bun --bun ../schema/script/config-schema.ts config.json
        '';
        postInstall = (old.postInstall or "") + ''
          install -Dm644 config.json $out/share/config.json
        '';
        passthru = old.passthru // {
          jsonschema.config = "${finalAttrs.finalPackage}/share/config.json";
        };
      });

  # Workaround 3: the desktop app bundles the CLI. Upstream's desktop.nix stages
  # it in $OPENCODE_CLI_DIST, but packages/desktop/script/build.ts ignores that
  # and only looks in packages/cli/dist (prod channel: "build it first" error).
  # Stage the fixed CLI there too, same layout (<npm pkg name>/bin + package.json).
  opencode-desktop =
    (opencodePkgs.opencode-desktop.override { inherit opencode; }).overrideAttrs
      (old: {
        preBuild = (old.preBuild or "") + ''
          cli_package=$(cd packages/desktop && bun -e 'import { getCurrentCli } from "./script/utils.ts"; console.log(getCurrentCli().package.replace("@opencode/", ""))')
          mkdir -p "packages/cli/dist/$cli_package/bin"
          cp ${lib.getExe opencode} "packages/cli/dist/$cli_package/bin/opencode"
          printf '{"version":"%s"}\n' "$OPENCODE_VERSION" > "packages/cli/dist/$cli_package/package.json"
        '';
      });
in
{
  imports = [ ./serve.nix ]; # `opencode serve` as a user service

  # The CLI is installed by hm-module.nix (programs.opencode, into melody's
  # profile) from m2.opencode.package; serve.nix runs that same package.
  environment.systemPackages = [ opencode-desktop ];

  home-manager.users.melody = {
    imports = [ ./hm-module.nix ];
    m2.opencode.package = opencode;
  };
}
