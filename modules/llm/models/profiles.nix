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
#   fallback — ids put LAST (after matches): the warm strategy's last resort.
# Unknown ids, and a profile that ends up with no targets, fail the build.
#
#   effort   — OpenCode's default reasoning effort when no variant is picked
#              (defaults to the first target's)
#   strategy — llama-swap selector strategy (default "warm": keeps targets warm
#              for fast swaps but still lets idle models unload; "fit" picks
#              by what the capacity router would have to unload)
#   settings — llama-swap selector settings, passed through (e.g. no_evict)
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

  # Home Assistant voice ("hey jarvis"). HA sends model "voice" (with
  # enable_thinking + reasoning_effort=low; both voice models run -rea off and
  # ignore it). Rule: voice NEVER touches a coder; a loaded coder counts as busy
  # (llama-swap can't tell busy from idle).
  #
  # `fit` (needs the capacity router, llama-swap/default.nix) asks the router what
  # each target would unload and picks the cheapest: lowest summed evict_cost,
  # then fewest unloads, then ready > starting > cold, then target order.
  # no_evict: never pick a target that unloads anything (429 instead).
  #   GPU free (nothing / voice-gpu in vram)  -> voice-gpu, cold-starting it if
  #                                              needed (~0.15 s turns warm)
  #   coder loaded or loading (claims all vram) -> voice-gpu would evict it, so
  #                                              the CPU model (~3-5 s turns)
  # The catch: once the CPU model is loaded it wins every tie (ready beats cold),
  # so after a coder unloads, voice stays on the CPU until the CPU model's ttl
  # (presets.nix voiceModel, 600 s idle) unloads it. Its cold start re-prefills
  # HA's ~9k-token prompt: ~55-65 s for the first turn.
  voice = {
    name = "Voice";
    description = "HA voice: GPU voice model when no coder holds the RTX, else CPU model";
    effort = "low";
    strategy = "fit";
    settings.no_evict = true;
    targets = [
      "voice-gpu-Qwen3.5-4B"
      "voice-Qwen3.5-4B"
    ];
  };
}
