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

  # Home Assistant voice ("hey jarvis"). HA sends model "voice" with
  # chat_template_kwargs.enable_thinking=true + reasoning_effort=low (the voice
  # models run -rea off and ignore it; coders like Tiel are reasoning-mandatory
  # and stop calling tools without it). The warm strategy picks the first READY
  # target in order, and only one vram member runs at a time, so:
  #   1. voice-gpu-Qwen3.5-4B, preloaded while the GPU is idle: ~0.3 s turns;
  #   2. else whichever coder OpenCode swapped in (it evicted voice-gpu):
  #      ~1 s turns with low-effort thinking (eval: Tiel 13/15, thinking off 4/15);
  #   3. else (a coder is still loading) the always-on CPU model: ~3-5 s turns.
  # Voice never triggers a swap itself; targets[0] is only cold-started if nothing
  # at all is running. After a coder takes the GPU, voice-gpu stays out until
  # llama-swap restarts (coders have no ttl).
  # Caveats: warm does not know "busy". If OpenCode is mid-generation on the
  # loaded coder (-np 1), voice queues behind it. And a voice turn replaces the
  # coder's slot, though --cache-ram restores OpenCode's prefix afterwards.
  voice = {
    name = "Voice";
    description = "HA voice: GPU voice model, else warm coder, else always-on CPU model";
    effort = "low";
    prefer = [ "voice-gpu-Qwen3.5-4B" ];
    match = [ "vram" ];
    fallback = [ "voice-Qwen3.5-4B" ];
  };
}
