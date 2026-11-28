# opencode — packages + the generated ~/.config/opencode/opencode.json.
#
# The whole generated config lives in ./hm-module.nix, shared verbatim with
# the tablet (Arch, standalone home-manager) — see that file's header. This
# file is only the desktop's NixOS side: the desktop app package + the
# headless `opencode serve` service.
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
{ pkgs, ... }:
{
  imports = [ ./serve.nix ]; # `opencode serve` at boot (headless)

  # The CLI comes from hm-module.nix (programs.opencode, into melody's
  # profile); serve.nix (headless) runs `opencode serve` from pkgs.opencode.
  environment.systemPackages = [ pkgs.opencode-desktop ];

  home-manager.users.melody.imports = [ ./hm-module.nix ];
}
