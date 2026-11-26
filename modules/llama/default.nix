# llama-swap — local LLM serving + model swapping (all boot modes).
#
#   helpers.nix  — model / valV3 / titleModel builders (all the llama-server flags)
#   models.nix   — the models, keyed by routing group (vram / igpu)
#   profiles.nix — runtime-switchable selectors
#
# `settings` is freeform YAML; the NixOS module runs `llama-swap -validate`
# against config-schema.json at build time, so typos fail `nixos-rebuild build`.
#
# Don't use `aliases` / `setParamsByID`: aliases show up as separate /v1/models
# rows in OpenCode, and setParamsByID overrides the reasoning_effort that
# OpenCode's variants send. Variants are declared in the OpenCode config.
{
  config,
  lib,
  pkgs,
  pkgs-llama,
  ...
}:
let
  llama = import ./helpers.nix { inherit lib pkgs-llama; };
  groups = import ./models.nix { inherit (llama) model valV3 titleModel; };
  models = groups.vram // groups.igpu;
  selectors = import ./profiles.nix;
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
    port = 9930;
    listenAddress = "0.0.0.0"; # reachable from other devices on the LAN
    settings = {
      inherit models selectors;
      healthCheckTimeout = 500; # seconds; big models load slowly
      sendLoadingState = false; # don't inject loading updates into reasoning
      includeAliasesInList = false;

      routing.router.settings.groups = {
        # main coders: one at a time, and running one unloads the others
        vram = {
          swap = true;
          exclusive = true;
          members = lib.attrNames groups.vram;
        };
        # title models: always resident (the vram group can't unload them), coexist
        igpu = {
          swap = false;
          exclusive = false;
          persistent = true;
          members = lib.attrNames groups.igpu;
        };
      };
    };
  };

  assertions = lib.concatLists (
    lib.mapAttrsToList (
      sel: s:
      map (t: {
        assertion = models ? ${t};
        message = "llama-swap selector '${sel}' targets unknown model '${t}'";
      }) s.targets
    ) selectors
  );

  # The service is a DynamicUser with a restricted environment, so point the
  # Vulkan loader straight at Intel's ICD (exposes the iGPU as Vulkan0; the RTX
  # is reached through CUDA).
  systemd.services.llama-swap.environment.VK_ICD_FILENAMES = config.meldesktop.intelIcd;
}
