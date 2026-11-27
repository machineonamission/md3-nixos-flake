# profiles.nix — runtime-switchable model sets.
#
# Each one becomes a llama-swap selector (the UI/API "profiles") AND an
# OpenCode model with the same id, so `llama-swap/coder#high` routes through
# the `coder` selector. OpenCode limits/capabilities are derived from the targets.
#
# Targets come from tags (models.nix `tags` + the derived ones in default.nix):
#   match    — tags a model must ALL have; "!tag" means it must NOT have it.
#              Every model matching is a target, in alphabetical order.
#   prefer   — ids put first, in this order. With strategy "warm" the first
#              target is the one cold-started when nothing is loaded.
#   targets  — an explicit list instead of match (or extra ids added to it).
# Unknown ids, and a profile that ends up with no targets, fail the build.
#
#   effort   — OpenCode's default reasoning effort when no variant is picked
#              (defaults to the first target's)
#   strategy — llama-swap selector strategy (default "warm": keeps targets warm
#              for fast swaps but still lets idle models unload)
#
# See what a profile resolves to:
#   nix eval .#nixosConfigurations.MelDesktop3.config.specialisation.saver.configuration.services.llama-swap.settings.selectors.moe.targets
#   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"moe"}'
{
  # hand-picked: the two best safe coders
  coder = {
    name = "Coder";
    description = "Coder GPU Aligned";
    effort = "medium";
    targets = [
      "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
      "Tiel-Coder-35B-A3B"
    ];
  };

  coder-unsafe = {
    name = "Coder (Unsafe)";
    description = "Unsafe/Abliterated Coder GPU";
    effort = "high";
    match = [
      "tiel"
      "unsafe"
      "!mtp"
    ];
  };

  coder-mtp = {
    name = "Coder (MTP)";
    description = "MTP Speculative Tiel GPU";
    effort = "high";
    match = [
      "tiel"
      "mtp"
    ];
    prefer = [ "Tiel-Coder-35B-A3B-MTP" ];
  };

  moe = {
    name = "MoE 35B";
    description = "Other 35B-A3B / 29B / Occamy MoE GPU";
    effort = "medium";
    match = [ "moe" ];
    prefer = [ "Tiel-Coder-35B-A3B" ];
  };

  hybrid = {
    name = "Hybrid Coder";
    description = "Dense/Hybrid Qwen3.8-27B Coder GPU";
    effort = "high";
    match = [
      "dense"
      "!unsafe"
    ];
    prefer = [ "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF" ];
  };

  hybrid-unsafe = {
    name = "Hybrid Coder (Unsafe)";
    description = "Uncensored/Abliterated Dense/Hybrid Qwen3.8-27B Coder GPU";
    effort = "high";
    match = [
      "dense"
      "unsafe"
    ];
  };

  # Used by OpenCode's `title` agent. Thinking off (the title models' default).
  title = {
    name = "Title";
    description = "Title Generation (No Reasoning)";
    match = [ "title" ];
    prefer = [ "Qwen3.5-2B" ];
  };
}
