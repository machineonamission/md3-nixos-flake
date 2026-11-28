# presets.nix — turn a short model literal (models.nix) into a full spec.
#
# A spec is plain data with every default filled in. It names no backend:
# modules/llm/llama-swap turns it into llama-server flags, modules/llm/opencode into an
# OpenCode model entry, so numbers like ctx / maxOutput / reasoningBudget are
# defined exactly once and both sides always agree.
#
#   model      — a main coder on the RTX (CUDA0), full APEX-I-NanoPlus flag set
#   valV3      — `model` preset for the Qwen3.8-27B VAL-APEX-I-NanoPlus-V3 family
#   flashNext  — `model` preset for the Qwen3.8-Flash-Coder / Flash-Next MoE slices
#   tieredModel — a model served by the ruriww fork's serve.sh (ruby-llama-serve)
#   titleModel — a tiny title-generation model on the Intel iGPU (Vulkan0)
{
  lib,
  compactionBufferPct, # OpenCode's compaction.buffer in %, see default.nix
}:
let
  # Arguments (only name + hf are required):
  #   hfFile        — exact GGUF in the repo (-hff), so sidecars (dflash, mmproj)
  #                   are never auto-picked as the primary model
  #   image         — multimodal. mmproj stays on the CPU unless offloadMMProj:
  #                   Intel ANV Vulkan garbles clip_encode.
  #   ctx           — context window (-c, and OpenCode's limit)
  #   fitCtx        — if set, -c is omitted and `--fit on` may shrink context to
  #                   this floor before it offloads layers to system RAM
  #   fitt          — per-model override of the --fit headroom (MiB), default
  #                   null = use the mode's `meldesktop.llm.fitTarget`
  #                   (modes/specialisations.nix: normal 1536, saver 512,
  #                   headless 128). --fit already measures free VRAM at load
  #                   time; the headroom only guards against something else
  #                   (KWin, an Electron GPU process) growing mid-generation =
  #                   CUDA OOM. Too thin does bite: 2026-11-27 Tiel-Coder-35B-A3B
  #                   in saver at 128 aborted with "CUDA error: out of memory" in
  #                   process_ubatch on the FIRST request (--no-warmup defers the
  #                   compute-buffer hit), with ~0.8 GB of other dGPU use.
  #   kvq           — KV-cache quant for K and V. Keep them equal: only symmetric
  #                   q8_0 has a CUDA FlashAttention kernel.
  #   np            — parallel slots (1 = full context, no KV duplication)
  #   quant         — label surfaced in metadata
  #   mtp           — speculative decoding, see mtpFlags in llama/helpers.nix:
  #                   null | "self" | { file; repo ? hf; nMax ? 2; device ? "igpu"; }
  #   effort        — OpenCode's default reasoning effort (default of the model's
  #                   supported `efforts`; low|medium|high for standard models,
  #                   low|medium|xhigh for the EfficientThink/DAU template family)
  #   reasoningBudget — hard cap (tokens) on the thinking phase (--reasoning-budget)
  #   efforts       — the reasoning_effort levels this model's chat template
  #                   actually accepts (reflected in OpenCode's capabilities and
  #                   generated variants). Standard APEX models use low|medium|high;
  #                   the EfficientThink family uses low|medium|xhigh (its template
  #                   rejects "high"). Set this per model in models.nix.
  #   tags          — free-form labels profiles.nix matches on (family, "unsafe",
  #                   "moe"/"dense", ...). default.nix adds the derivable ones.
  #   extra         — raw llama-server flags appended at the end
  model =
    {
      name,
      hf,
      hfFile ? null,
      image ? false,
      ctx ? 262144,
      fitCtx ? null,
      mtp ? null,
      fitt ? null,
      kvq ? "q8_0",
      np ? 1,
      quant ? "APEX-I-NanoPlus",
      offloadMMProj ? false,
      effort ? "medium",
      reasoningBudget ? 16384,
      efforts ? [
        "low"
        "medium"
        "high"
      ],
      tags ? [ ],
      extra ? [ ],
    }:
    {
      kind = "coder";
      tools = true;
      maxOutput = 32768;
      # hard cap on the thinking phase so a reasoning doom-loop can't eat the context
      inherit
        reasoningBudget
        name
        hf
        hfFile
        image
        ctx
        fitCtx
        mtp
        fitt
        kvq
        np
        quant
        offloadMMProj
        effort
        efforts
        tags
        extra
        ;
    };

  # 27B dense hybrid, ~11–13 GB: won't fully fit 16 GB VRAM, so a 128K --fit-ctx
  # floor lets --fit spend VRAM on layers instead of KV cache. Embedded MTP head.
  valV3 =
    args:
    model (
      {
        quant = "VAL-APEX-I-NanoPlus-V3";
        image = true;
        ctx = 131072;
        fitCtx = 131072;
        mtp = "self";
      }
      // args
      // {
        tags = [ "dense" ] ++ args.tags or [ ];
      }
    );

  # Qwen3.8 "Flash" (Flash-Coder, Flash-Next): MoE slices that are NOT a 27B.
  # IsValorum's Flash-Coder is a `moe-slice` of the 85 GB base (352 of 512 experts
  # pruned against English Python + SWE-bench, 2.90 BPW), so it is a fragile
  # English-only coding specialist, and its own chat template (always opens
  # <think> unless enable_thinking=false) pairs badly with a long thinking budget:
  # at the plain `model` defaults it looked fast (~46 t/s) but produced garbage
  # ("return null;" loops after a ~16k-token "Thought 5m"). So here:
  #   - thinking is OFF by default (effort "none" -> enable_thinking=false -> the
  #     template emits an empty <think></think>); low/medium/high/xhigh variants
  #     still turn it on, but capped at 4096 tokens instead of 16384
  #   - efforts are what the template accepts (low|medium|high|xhigh + none/off)
  # Untested on the box: the debugging session couldn't load it next to the live
  # coder (VRAM contention), so if it still misbehaves look at ctx first (the
  # vendor quickstart uses 65536, we default to the native 262144).
  flashNext =
    args:
    model (
      {
        effort = "none";
        efforts = [
          "low"
          "medium"
          "high"
          "xhigh"
        ];
        reasoningBudget = 4096;
      }
      // args
      // {
        tags = [ "qwen3.8-flash" ] ++ args.tags or [ ];
      }
    );

  # Qwen3.8-Flash-Next on the ruriww fork's tiered MoE runtime (~94 GiB GGUF:
  # dense weights + an expert cache in VRAM, the other experts mmapped from the
  # NVMe). llama-swap runs the fork's serve.sh (160k context, MTP, chat template,
  # every MOE_* knob); the fields below override what has to agree with OpenCode
  # (effort caps, context room) and describe it to OpenCode, using the fork's
  # SERVE.md values: output 32000, efforts low..max (max = chained thinking).
  #   files — { model; mtp ? null; mmproj ? null; }, each a source as in
  #           llama-swap/helpers.nix fileOf: an absolute path (used in place),
  #           { url; hash; }, or { hf; file; hash; rev ? "main"; } (both fetched
  #           into the Nix store). mmproj turns images on (set image = true too).
  tieredModel =
    {
      name,
      quant,
      files,
      ctx ? 163840,
      maxOutput ? 32000,
      image ? false,
      effort ? "low",
      efforts ? [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ],
      tags ? [ ],
      # Tuning on top of the fork's serve.sh (each measured on this box, see the model entry):
      #   env  — MOE_* overrides, exported right before serve.sh's exec
      #   args — extra llama-server flags (last one wins over serve.sh's)
      #   cpus — taskset CPU list for the whole server (null = unpinned)
      env ? { },
      args ? [ ],
      cpus ? null,
      # Host-RAM prompt cache (MiB) for juggling OpenCode sessions. The fork's fast
      # paths (MOE_IDX_COMPACT, MOE_RS_REPLAY, KV lending) need ONE sequence, so it
      # stays -np 1 and an idle session's state (KV + recurrent checkpoints) is parked
      # here when another session's request arrives (--cache-idle-slots), then restored
      # instead of re-prefilled. ~14 KiB/token of q8_0 KV + 3 x ~113 MiB checkpoints:
      # a 90k-token session is ~1.6 GiB, so 8192 holds ~5 of those (oldest evicted
      # first; a state bigger than the limit is not cached at all). serve.sh's own
      # -cram 2048 fits about one. Parked states are anonymous memory, so under
      # pressure they go to swap instead of evicting the expert page cache wholesale.
      cacheRamMiB ? 8192,
      # Thinking cap per effort (tokens) and the room the server keeps for the answer
      # on top; nix owns these and passes them to serve.sh as MOE_EFFORT_BUDGETS /
      # MOE_THINK_ANSWER (serve.sh's own values: the ones below, max 70%).
      effortCaps ? {
        low = 1000;
        medium = 4000;
        high = 12000;
        xhigh = 20000;
      },
      maxPct ? 70, # `max` effort: thinking may use this % of the context left before compaction
      answer ? 12000,
      # DCP compress nudges (opencode/dcp.nix) in absolute tokens: reminders from
      # `min`, strong nudges from `max`. Fixed, NOT scaled with ctx: the window is
      # headroom before native compaction, while sessions are kept around the size
      # that decodes fast (KV lending: every token in the session costs expert-cache
      # VRAM; measured ~62 t/s at 80-120k, ~55 at 120-140k). null = DCP's % defaults.
      compressAt ? {
        min = 70000;
        max = 113000;
      },
    }:
    let
      # Context room, so a long session compacts instead of erroring (2026-11-27: a
      # 133k-token session at xhigh got the fork's "request exceeds the context
      # window", 133398 + 20000 cap + 12000 answer > 163840, and OpenCode compacted
      # out of the blue). OpenCode has one limit per model, not per effort, so:
      #   - the server FITS the cap when the room runs short (MOE_THINK_ROOM_ERROR=0:
      #     cap -> max(cap / 2, room - answer)) instead of returning that error;
      #   - OpenCode's input limit leaves exactly the worst fitted case free:
      #     ctx - (largest cap / 2 + answer) = 163840 - 22000 = 141840, then compacts
      #     compactionBufferPct (5 %) below that (~134.7k), so every effort, xhigh
      #     included, still gets at least half its cap plus a full answer;
      #   - `max` sizes its chained thinking to the context left before THAT point
      #     (MOE_THINK_CHAIN_RESERVE = ctx - the compaction point; the fork assumed 33000).
      # DCP's nudges (opencode/dcp.nix) are relative to the same inputLimit.
      inputLimit = ctx - (lib.foldl' lib.max 0 (lib.attrValues effortCaps) / 2 + answer);
      compactAt = inputLimit - inputLimit * compactionBufferPct / 100;
    in
    {
      kind = "tiered";
      tools = true;
      mtp = "sidecar"; # in serve.sh; only here for the derived "mtp" tag
      reasoningBudget = effortCaps.xhigh or (lib.foldl' lib.max 0 (lib.attrValues effortCaps)); # max has no fixed one
      inherit inputLimit compressAt;
      # derived server knobs first, the model entry's own env overrides them
      env = {
        MOE_EFFORT_BUDGETS = lib.concatStringsSep "," (
          lib.mapAttrsToList (e: c: "${e}:${toString c}") effortCaps ++ [ "max:${toString maxPct}%" ]
        );
        MOE_THINK_ANSWER = answer;
        MOE_THINK_ROOM_ERROR = 0;
        MOE_THINK_CHAIN_RESERVE = ctx - compactAt;
      }
      // env;
      inherit
        name
        quant
        files
        ctx
        maxOutput
        image
        effort
        efforts
        tags
        args
        cpus
        cacheRamMiB
        ;
    };

  # Tiny always-ready title models on the iGPU. Thinking off by default.
  # presencePenalty is a STRING because Nix renders floats as "1.500000".
  titleModel =
    {
      name,
      hf,
      ctx,
      reasoningBudget,
      presencePenalty,
      effort ? "none",
      efforts ? [
        "low"
        "medium"
        "high"
      ],
      tags ? [ ],
    }:
    {
      kind = "title";
      tools = false;
      image = false;
      maxOutput = 2048;
      inherit
        name
        hf
        ctx
        reasoningBudget
        presencePenalty
        effort
        efforts
        tags
        ;
    };

  # Home Assistant voice model (the `voice` selector in profiles.nix), thinking off.
  # A voice turn is 2-3 short tool rounds, so generation speed is what you wait on.
  #   hf      — "repo:QUANT" (llama-server -hf syntax)
  #   device  — "cpu" (taskset-pinned to the P-cores) or "cuda" (all on the RTX)
  #   vramMiB — what a cuda model claims of llama-swap's `vram` capacity pool
  #             (measured: Qwen3.5-4B Q4_K_M at 16k ctx = 3518 MiB)
  #   ttl     — llama-swap idle unload, seconds (0 = never). The CPU model MUST
  #             unload eventually: while it is loaded the `fit` selector prefers it
  #             over a cold GPU model, so the GPU one would never come back.
  #   cpus    — taskset CPU list (0-15 = the 8 P-cores incl. HT siblings on the 14700K)
  voiceModel =
    {
      name,
      hf,
      device ? "cpu",
      vramMiB ? 3600,
      ttl ? (if device == "cpu" then 600 else 0),
      ctx ? 16384,
      cpus ? "0-15",
      threads ? 8,
      batchThreads ? 16,
      efforts ? [
        "low"
        "medium"
        "high"
      ],
      tags ? [ ],
      extra ? [ ],
    }:
    {
      kind = "voice";
      tools = true;
      image = false;
      maxOutput = 512;
      reasoningBudget = 0;
      effort = "none";
      inherit
        name
        hf
        device
        vramMiB
        ttl
        ctx
        cpus
        threads
        batchThreads
        efforts
        tags
        extra
        ;
    };
in
{
  inherit
    model
    valV3
    flashNext
    tieredModel
    titleModel
    voiceModel
    ;
}
