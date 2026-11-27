# opencode — packages + the generated ~/.config/opencode/opencode.json.
#
#   settings.nix    — the config as a Nix value (agents, plugins, mcp, ...)
#   providers.nix   — providers; llama-swap models generated from modules/llm
#   permissions.nix — global rules + the M2 agents
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
{
  lib,
  pkgs,
  config,
  ...
}:
let
  home = config.users.users.melody.home;
  secrets = "${home}/.config/opencode/secrets";
  catalog = import ../llm { inherit lib; };
in
{
  # The CLI comes from programs.opencode below (into melody's profile);
  # modules/headless.nix runs `opencode serve` from pkgs.opencode directly.
  environment.systemPackages = [ pkgs.opencode-desktop ];

  home-manager.users.melody.programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    validateFiles.config = true;
    settings = import ./settings.nix {
      inherit
        lib
        catalog
        home
        secrets
        ;
    };
  };
}
