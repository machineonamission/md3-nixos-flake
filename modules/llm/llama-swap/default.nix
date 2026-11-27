# llama-swap — local LLM serving + model swapping (saver + headless modes).
#
# The models and profiles themselves live in modules/llm/models (shared with the
# OpenCode config); this module only turns them into llama-swap settings:
#   helpers.nix — spec -> llama-swap entry (all the llama-server flags)
#
# `settings` is freeform YAML; the NixOS module runs `llama-swap -validate`
# against config-schema.json at build time, so typos fail `nixos-rebuild build`.
#
# Don't use `aliases` / `setParamsByID`: aliases show up as separate /v1/models
# rows in OpenCode, and setParamsByID overrides the reasoning_effort that
# OpenCode's variants send. Variants are generated in modules/llm/opencode.
{
  config,
  lib,
  pkgs-llama,
  ...
}:
let
  catalog = import ../models { inherit lib; };
  llama = import ./helpers.nix { inherit lib pkgs-llama; };
  cfg = config.services.llama-swap;
in
lib.mkIf config.meldesktop.llm {
  # The same CUDA+Vulkan build llama-swap runs (llama-server, llama-cli, ...).
  environment.systemPackages = [
    llama.llama-cpp
    cfg.package
  ];

  services.llama-swap = {
    enable = true;
    inherit (catalog) port;
    listenAddress = "0.0.0.0"; # reachable from other devices on the LAN
    settings = {
      models = lib.mapAttrs (_: llama.entry) catalog.models;
      selectors = lib.mapAttrs (_: p: {
        inherit (p)
          strategy
          name
          description
          targets
          ;
      }) catalog.profiles;
      healthCheckTimeout = 500; # seconds; big models load slowly
      sendLoadingState = false; # don't inject loading updates into reasoning
      includeAliasesInList = false;

      routing.router.settings.groups = {
        # main coders: one at a time, and running one unloads the others
        vram = {
          swap = true;
          exclusive = true;
          members = lib.attrNames catalog.groups.vram;
        };
        # title models: always resident (the vram group can't unload them), coexist
        igpu = {
          swap = false;
          exclusive = false;
          persistent = true;
          members = lib.attrNames catalog.groups.igpu;
        };
        # CPU-only always-on models (the HA voice fallback): never unloaded, never
        # unload anything, and preloaded below so the `voice` selector always has
        # a ready target.
        cpu = {
          swap = false;
          exclusive = false;
          persistent = true;
          members = lib.attrNames catalog.groups.cpu;
        };
      };

      # CPU voice first (always resident), then the GPU voice model so the idle RTX
      # serves HA until a coder evicts it (the cpu group is persistent, so loading
      # an exclusive vram member can't unload it). See profiles.nix `voice`.
      hooks.on_startup.preload = lib.attrNames catalog.groups.cpu ++ [ "voice-gpu-Qwen3.5-4B" ];
    };
  };

  # The service is a DynamicUser with a restricted environment, so point the
  # Vulkan loader straight at Intel's ICD (exposes the iGPU as Vulkan0; the RTX
  # is reached through CUDA).
  systemd.services.llama-swap.environment.VK_ICD_FILENAMES = config.meldesktop.intelIcd;
}
