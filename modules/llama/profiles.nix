# profiles.nix — services.llama-swap.settings.selectors.
#
# Runtime-selectable model-ID rewrites, switched via the UI/API (NOT the
# reasoning-effort variants, which are declared in opencode.jsonc). Only ONE
# profile may be active at a time; hooks.on_startup.profile picks the startup
# one. `profile` fills in the shared `strategy = "warm"` so each entry is just
# its name / description / targets.
#
# WHAT A SELECTOR DOES
#   Rewrites the active model ID to its target(s) at runtime. A selector with
#   ONE target swaps to that model; a selector with MULTIPLE targets is a quick
#   "pick one of these" swap. Every target MUST be a real model id defined in
#   models.nix AND a member of a routing group (vram / igpu) in default.nix,
#   otherwise llama-swap can't load it. This file therefore covers EVERY model
#   in those two groups — nothing loadable is unreachable.
#
# TWO KINDS OF SELECTOR:
#   * FULL coders — general-purpose defaults you want most of the time.
#   * NARROW selectors — quick swaps to a specific architecture / case:
#       hybrid   — dense/hybrid coder (Qwen3.8-27B family)
#       system   — + extended thinking (EfficientThink) for complex tasks
#       moe      — the 35B-A3B MoE architecture (the one you actually want)
#       moe-35b  — other 35B-A3B / 29B / Occamy MoE models
#       mini     — small/fast text models (quick chat, low VRAM)
#
# Swap at runtime:
#   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"moe"}'
{ }:
let
  profile =
    {
      name,
      description,
      targets,
    }:
    {
      # warm-start keeps the target's weights resident (fast swap) but lets idle
      # models unload — better VRAM hygiene than pin, which never unloads.
      strategy = "warm";
      inherit name description targets;
    };
  # Same shape, just shorter for the common one-target case.
  one =
    {
      name,
      description,
      target,
    }:
    profile {
      inherit name description;
      targets = [ target ];
    };
in
{
  # ---- FULL coders (general purpose, default reasoning + agentic) ----------
  "coder" = profile {
    name = "Coder";
    description = "Coder GPU Aligned";
    target = [
      "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Tiel-Coder-35B-A3B"
      ];
  };

  "coder-unsafe" = profile {
    name = "Coder (Unsafe)";
    description = "Unsafe/Abliterated Coder GPU";
    targets = [
      "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF"
      ];
  };

  # Cyber Tiel NanoPlus ships a SEPARATE draft head in the same repo — self-
  # contained speculative decode. Swap to it at runtime:
  #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"coder-mtp"}'
  "coder-mtp" = profile {
    name = "Coder (MTP)";
    description = "MTP Speculative Cyber Tiel GPU";
    targets = [
      "Tiel-Coder-35B-A3B-MTP"
      "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
    ];
  };

  # ---- MoE (35B-A3B) ------------------------------------------------------
  # "moe" — the default coder (Tiel, 35B-A3B MoE). Preferred over every other
  # MoE — this is the MoE you actually want. Kept as its own selector so you can
  # pin the MoE architecture explicitly.
  # Other 35B-A3B / 29B / Occamy MoE coders (text + vision variants).
  "moe" = profile {
    name = "MoE 35B";
    description = "Other 35B-A3B / 29B / Occamy MoE GPU";
    targets = [
      "Tiel-Coder-35B-A3B"
      "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF"
      "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
      "Tiel-Coder-35B-A3B-MTP"
      "Ornith-1.5-35B-A3B"
      "MiniCPM-V-4.7-35B-A3B"
      "MiniCPM-V-4.7-35B-A3B-MTP"
      "MiniCPM-V-4.7-35B-A3B-Abliterated"
      "Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF"
      "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF"
      "Occamy-1.0"
      "Qwen3.6-35B-A3B-MTP"
    ];
  };

  # ---- Hybrid / dense (Qwen3.8-27B VAL-APEX-NanoPlus-V3) ------------------
  # Dense-hybrid coders. "hybrid" is the base family; "system" adds extended
  # thinking (EfficientThink); "system-uncen" is the uncensored twin-turbo.
  "hybrid" = profile {
    name = "Hybrid Coder";
    description = "Dense/Hybrid Qwen3.8-27B Coder GPU";
    targets = [
      "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
    ];
  };

    # ---- Hybrid / dense (Qwen3.8-27B VAL-APEX-NanoPlus-V3) ------------------
  # Dense-hybrid coders. "hybrid" is the base family; "system" adds extended
  # thinking (EfficientThink); "system-uncen" is the uncensored twin-turbo.
  "hybrid-unsafe" = profile {
    name = "Hybrid Coder";
    description = "Dense/Hybrid Qwen3.8-27B Coder GPU";
    targets = [
      "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
    ];
  };


  # ---- Title generation (tiny iGPU models, Vulkan0) -----------------------
  "title" = profile {
    name = "Title";
    description = "Title Generation (No Reasoning)";
    targets = [
      "Qwen3.5-2B"
      "Qwen3.5-0.8B"
    ];
  };
}
