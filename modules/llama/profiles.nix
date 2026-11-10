# profiles.nix — services.llama-swap.settings.selectors.
#
# Runtime-selectable model-ID rewrites, switched via the UI/API (NOT the
# reasoning-effort variants, which are declared in opencode.jsonc). Only ONE
# profile may be active at a time; hooks.on_startup.profile picks the startup
# one. `profile` fills in the shared `strategy = "pin"` so each entry is just
# its name / description / targets.
#
# TWO KINDS OF SELECTOR:
#   * FULL coders — general-purpose models (default reasoning + agentic). The
#     defaults you want most of the time. Kept exactly as they were.
#   * NARROW selectors — quick swaps to a specific architecture / case:
#       moe        — a pure Mixture-of-Experts coder (35B-A3B), distinct from
#                    the default full coder so you can A/B the architectures
#       mixed      — a dense / hybrid coder (Qwen3.8-27B family)
#       swap-back  — revert to the default full coder
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
      strategy = "pin"; # warm-start keeps the target's weights resident
      inherit name description targets;
    };
in
{
  # ---- FULL coders (general purpose) --------------------------------------
  "coder" = profile {
    name = "Coder";
    description = "Coder GPU Aligned";
    targets = [
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

  "coder-mtp" = profile {
    name = "Coder (MTP)";
    description = "MTP Speculative Cyber Tiel GPU";
    targets = [
      "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
    ];
  };

  # ---- NARROW selectors (specific architecture / case) --------------------
  # "moe" — pure Mixture-of-Experts coder, 35B-A3B. Distinct from the default
  # full coder (Tiel) so you can compare the two architectures.
  "moe" = profile {
    name = "MoE Coder";
    description = "Pure Mixture-of-Experts Coder GPU";
    targets = [
      "Ornith-1.5-35B-A3B"
    ];
  };

  # "mixed" — dense / hybrid coder, Qwen3.8-27B VAL-APEX-NanoPlus-V3.
  "mixed" = profile {
    name = "Hybrid Coder";
    description = "Dense/Hybrid Coder GPU";
    targets = [
      "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
    ];
  };

  # "swap-back" — revert to the default full coder (Tiel).
  "swap-back" = profile {
    name = "Swap Back";
    description = "Revert to Default Full Coder GPU";
    targets = [
      "Tiel-Coder-35B-A3B"
    ];
  };

  # ---- title generation (iGPU) --------------------------------------------
  "title" = profile {
    name = "Title";
    description = "Title Generation (No Reasoning)";
    targets = [
      "Qwen3.5-2B"
      "Qwen3.5-0.8B"
    ];
  };
}
