# llama — llama-swap module (local LLM serving + model swapping).
#
# The module WORKS like this:
#   `services.llama-swap.settings` is a FREEFORM YAML value. The module
#   serialises it to config.yaml and runs `llama-swap -validate` at build
#   time (services.llama-swap.validateConfigFile, default true), which checks
#   it against config-schema.json. So you do NOT hand-translate the JSON schema
#   into Nix — add the fields you care about and let the validator catch typos
#   / wrong types at `nix build` time.
#
# SPLIT:
#   helpers.nix  — baseCmd / mtpExtra / model / titleModel (the shared macros)
#   models.nix   — settings.models  (drop-in model literals)
#   profiles.nix — settings.selectors (runtime model-ID rewrites)
#
# REASONING-VARIANT WARNINGS:
#   * OpenCode only auto-generates low/medium/high variants when the discovery
#     format advertises `reasoning_options`. The llama-swap format does NOT
#     populate that, so variants are declared EXPLICITLY in opencode.jsonc
#     (providers.llama-swap.models.<id>.variants) — not here.
#   * Do NOT use `aliases` / `setParamsByID` here: includeAliasesInList would
#     emit aliased ids as SEPARATE /v1/models rows, splitting the model in
#     OpenCode. setParamsByID's base rule would also override the request-body
#     reasoning_effort that OpenCode's own variant overlay sends.
#
# MODEL-DATA PASSING TO OpenCode (opencode-models-discovery plugin):
#   The plugin reads meta.llamaswap.max_input_tokens / max_output_tokens from
#   /v1/models to set the Input / Output limits. llama-swap doesn't emit these
#   by default, so they live in each model's `metadata` map and surface
#   verbatim in meta.llamaswap (only architecture/capabilities/... are capped).
{
  config,
  pkgs,
  lib,
  inputs,
  pkgs-llama,
  ...
}:
let
  llama = import ./helpers.nix { inherit lib pkgs-llama; };
in
{
  # LLaMA C++ CUDA build from source (pkgs-llama = nixpkgs-unstable + cudaSupport).
  environment.systemPackages = with pkgs-llama; [
    llama-cpp-cuda
    llama-swap
  ];

  services.llama-swap = {
    enable = true;
    port = 9930; # llama-swap OpenAI-compatible front door
    listenAddress = "0.0.0.0"; # let other devices reach the webui
    settings = {
      # ---- routing: iGPU group holds the tiny title models -----------------
      routing.router.settings.groups.igpu = {
        swap = true; # keep all members loaded; avoids unloading other groups
        exclusive = false;
        persistent = true; # other groups can't unload these members
        members = [
          "Qwen3.5-2B"
          "Qwen3.5-0.8B"
        ];
      };

      # ---- global ---------------------------------------------------------
      # healthCheckTimeout is in SECONDS (schema min 15, default 120); 500 is
      # fine for a big model that takes a while to load.
      healthCheckTimeout = 500;
      sendLoadingState = false; # don't inject loading updates into reasoning
      includeAliasesInList = false; # aliases are variants in opencode.jsonc, not separate /v1/models rows

      # ---- models (drop-in literals; all shared flags come from `model`) ----
      models = import ./models.nix { inherit (llama) model titleModel mtpExtra; };

      # ---- profiles (runtime-selectable model-ID rewrites) ----------------
      selectors = import ./profiles.nix { };
    };
  };

  # The service runs as a DynamicUser with a restricted PATH, so the Vulkan
  # loader can't find Intel's ICD via the default path. Point it directly at
  # Intel's x86_64 ICD so the iGPU is enumerable as Vulkan0 (the NVIDIA card is
  # reached via CUDA, so only Intel is listed on purpose).
  # CRITICAL: use the x86_64 ICD JSON, NOT the i686 one — the i686 JSON declares
  # library_arch "32" and the 64-bit loader silently rejects it, so the iGPU
  # never shows up.
  systemd.services.llama-swap.environment.VK_ICD_FILENAMES =
    "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";

  # The DynamicUser has no group memberships, so it can't open the NVIDIA
  # device nodes (root:video, 660) for CUDA even though PrivateDevices = false.
  # Uncomment to enable CUDA device access:
  # systemd.services.llama-swap.supplementaryGroups = [ "video" ];
}
