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
      # ---- routing: SEPARATE iGPU + VRAM swap groups ------------------------
      # Two independent groups so the two devices don't fight. The group router
      # (routing.router.use defaults to "group") is the classic setup: one
      # exclusive group for the big coders, one persistent group for the small
      # always-ready models. A model can belong to only ONE group, and every
      # member must be a real model id defined in models.nix — so every model
      # is listed in exactly one of these two groups.
      #
      #   vram  — the main coders on CUDA (RTX 5070 Ti).
      #           swap=true   => one coder at a time
      #           exclusive=true => running a coder unloads the other coders
      #
      #   igpu  — the tiny title models on Vulkan0 (Intel iGPU).
      #           persistent=true => the vram group can never unload these, so
      #                           titles are always resident and ready
      #           swap=false    => both title models coexist
      #
      # NOTE: image mmproj runs on the CPU (--no-mmproj-offload) per the baseCmd
      # decision in helpers.nix — the Vulkan0 path garbles every image model —
      # so it is NOT an igGPU member. The iGPU group only holds the title models.
      routing.router.settings.groups.vram = {
        swap = true; # one coder at a time on the RTX
        exclusive = true; # running a coder unloads the other coders
        members = [
          # full coders
          "Tiel-Coder-35B-A3B"
          "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF"
          "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
          # hybrid / dense Qwen3.8-27B family
          "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
          "Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF"
          # MoE coders
          "Tiel-Coder-35B-A3B-MTP"
          "Ornith-1.5-35B-A3B"
          "MiniCPM-V-4.7-35B-A3B"
          "MiniCPM-V-4.7-35B-A3B-MTP"
          "MiniCPM-V-4.7-35B-A3B-Abliterated"
          "Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF"
          "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF"
          "Occamy-1.0"
          "LFM2.5-24B-A2B"
          "Qwen3.6-35B-A3B-MTP"
          "Qwen3.8-Flash-Coder"
          "Qwen3.8-Flash-Next"
          "KAT-Coder-V2.5-Dev"
          "Sage-A1.5"
          "Flint"
          "T-Search"
          "Thomson-1.0-Small"
        ];
      };

      routing.router.settings.groups.igpu = {
        swap = false; # both title models coexist
        exclusive = false; # doesn't affect the vram group
        persistent = true; # the vram group can't unload these
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
