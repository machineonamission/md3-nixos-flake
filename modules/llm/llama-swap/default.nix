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
  pkgs,
  pkgs-llama,
  inputs,
  ...
}:
let
  catalog = import ../models { inherit lib; };
  llama = import ./helpers.nix {
    inherit lib pkgs-llama;
    llama-cpp-src = inputs.llama-cpp;
  };
  cfg = config.services.llama-swap;

  # Capacity router (routing below). One pool, the RTX's VRAM in MiB. Coders
  # use `--fit on`, which grabs whatever VRAM is free, so each claims the whole
  # pool: two coders, or a coder + the GPU voice model, can't coexist. CPU and
  # iGPU models claim nothing, so nothing evicts them and they evict nothing.
  vramMiB = 16000;
  routing =
    s:
    if s.kind == "coder" then
      {
        capacities.vram = vramMiB;
        evict_cost = 100; # never worth unloading for voice (the selector skips it anyway)
      }
    else if s.kind == "voice" then
      {
        inherit (s) ttl;
      }
      // lib.optionalAttrs (s.device == "cuda") { capacities.vram = s.vramMiB; }
    else
      { };
in
lib.mkIf config.meldesktop.llm {
  # The same CUDA+Vulkan build llama-swap runs (llama-server, llama-cli, ...).
  environment.systemPackages = [
    llama.llama-cpp
    cfg.package
  ];

  services.llama-swap = {
    enable = true;
    package = import ./package.nix { inherit pkgs; };
    inherit (catalog) port;
    listenAddress = "0.0.0.0"; # reachable from other devices on the LAN
    settings = {
      models = lib.mapAttrs (_: s: llama.entry s // routing s) catalog.models;
      selectors = lib.mapAttrs (
        _: p:
        {
          inherit (p)
            strategy
            name
            description
            targets
            ;
        }
        // lib.optionalAttrs (p ? settings) { inherit (p) settings; }
      ) catalog.profiles;
      healthCheckTimeout = 500; # seconds; big models load slowly
      sendLoadingState = false; # don't inject loading updates into reasoning
      includeAliasesInList = false;

      routing.router = {
        use = "capacity";
        settings.capacity.pools.vram = vramMiB;
      };

      # No preload: the GPU voice model loads on demand (the `voice` selector) and
      # unloads on its ttl, so nothing sits in VRAM while idle.
    };
  };

  # The service is a DynamicUser with a restricted environment, so point the
  # Vulkan loader straight at Intel's ICD (exposes the iGPU as Vulkan0; the RTX
  # is reached through CUDA).
  systemd.services.llama-swap.environment.VK_ICD_FILENAMES = config.meldesktop.intelIcd;
}
