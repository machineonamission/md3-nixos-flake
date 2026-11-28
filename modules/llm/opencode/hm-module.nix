# hm-module.nix — the OpenCode home-manager module, SHARED by every machine:
#
#   * desktop (MelDesktop3, NixOS): imported via home-manager.users.melody.imports
#     from ./default.nix (flavor `desktop`, the default -> output byte-identical
#     to what the old inline block generated).
#   * tablet (Arch, standalone home-manager): the tablet flake takes this repo
#     as an input and imports this file. Flavor `tablet` drops the references
#     and plugins that only exist on the desktop.
#
# Everything in ~/.config/opencode that matters is generated here:
#   opencode.json  — programs.opencode.settings, schema-validated at build time
#   dcp.jsonc      — plain toJSON of ./dcp.nix
# Both end up as read-only symlinks into the store. Changing the config means
# editing Nix and rebuilding (`nixos-rebuild` / `home-manager switch`) — that
# is the whole point: the tablet cannot drift, because it builds the same file
# from the same source. Host-local extras (references, local plugins) are the
# ONLY things that may differ, via `m2.opencode.host`.
#
# Secrets are NOT generated: they stay in ~/.config/opencode/secrets/<name>
# (chmod 600, outside git) and are referenced as {file:...} in settings.nix.
# Each machine needs its own copy of them.
#
# The hand-edited files (AGENTS.md, M2-GIT-GITHUB.md, skills/) live in the
# machineonamission/opencode git repo, cloned on every machine at
# ~/.config/opencode — synced by git, never by Nix.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.m2.opencode;
  home = config.home.homeDirectory;
  secrets = "${home}/.config/opencode/secrets";
  catalog = import ../models { inherit lib; };
in
{
  options.m2.opencode = {
    host = lib.mkOption {
      type = lib.types.enum [
        "desktop"
        "tablet"
      ];
      default = "desktop";
      description = ''
        Which machine flavor of the shared OpenCode config to generate.
        `desktop` includes the desktop-only references (nixos-config,
        llama-gui-presets) and local plugins; `tablet` leaves them out.
      '';
    };
  };

  config = {
    programs.opencode = {
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
        flavor = cfg.host;
      };
    };

    # DCP plugin config. force: replaces any old hand-written dcp.jsonc.
    xdg.configFile."opencode/dcp.jsonc" = {
      force = true;
      text = builtins.toJSON (import ./dcp.nix { inherit lib catalog; });
    };
  };
}
