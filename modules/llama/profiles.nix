# profiles.nix — services.llama-swap.settings.selectors.
#
# Runtime-selectable model-ID rewrites, switched via the UI/API (NOT the
# reasoning-effort variants, which are declared in opencode.jsonc). Only ONE
# profile may be active at a time; hooks.on_startup.profile picks the startup
# one. `profile` fills in the shared `strategy = "warm"` so each entry is just
# its name / description / targets.
#
# Swap at runtime:
#   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"coder"}'
{ }:
let
  profile =
    {
      name,
      description,
      targets,
    }:
    {
      strategy = "warm"; # warm-start keeps the target's weights resident
      inherit name description targets;
    };
in
{
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

  "title" = profile {
    name = "Title";
    description = "Title Generation (No Reasoning)";
    targets = [
      "Qwen3.5-2B"
      "Qwen3.5-0.8B"
    ];
  };
}
