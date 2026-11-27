# presets.nix — turn a short model literal (models.nix) into a full spec.
#
# A spec is plain data with every default filled in. It names no backend:
# modules/llm/llama-swap turns it into llama-server flags, modules/llm/opencode into an
# OpenCode model entry, so numbers like ctx / maxOutput / reasoningBudget are
# defined exactly once and both sides always agree.
#
#   model      — a main coder on the RTX (CUDA0), full APEX-I-NanoPlus flag set
#   valV3      — `model` preset for the Qwen3.8-27B VAL-APEX-I-NanoPlus-V3 family
#   titleModel — a tiny title-generation model on the Intel iGPU (Vulkan0)
{ lib }:
let
  # Arguments (only name + hf are required):
  #   hfFile        — exact GGUF in the repo (-hff), so sidecars (dflash, mmproj)
  #                   are never auto-picked as the primary model
  #   image         — multimodal. mmproj stays on the CPU unless offloadMMProj:
  #                   Intel ANV Vulkan garbles clip_encode.
  #   ctx           — context window (-c, and OpenCode's limit)
  #   fitCtx        — if set, -c is omitted and `--fit on` may shrink context to
  #                   this floor before it offloads layers to system RAM
  #   fitt          — --fit headroom in MiB left free on the dGPU AFTER loading.
  #                   --fit already measures free VRAM at load time; this only
  #                   guards against something else (now ~only KWin: saver keeps
  #                   apps off the dGPU) growing mid-generation = CUDA OOM.
  #                   Embedded MTP heads allocate outside --fit's estimate: +256.
  #                   2026-11-27: 128 was too thin. Tiel-Coder-35B-A3B in saver
  #                   aborted with "CUDA error: out of memory" in process_ubatch
  #                   on the FIRST request, even "say hi" (--no-warmup defers the
  #                   compute-buffer hit), with ~0.8 GB of other dGPU use (KWin +
  #                   an Electron GPU process). Raised to 768 / 1024.
  #   fittHeadless  — the --fit-target to use in HEADLESS mode only (default null
  #                   = use `fitt`). Headless has no desktop, so nothing else
  #                   competes for VRAM and the headroom guard is pure waste: set
  #                   this to 0 to let the model claim the whole card.
  #   kvq           — KV-cache quant for K and V. Keep them equal: only symmetric
  #                   q8_0 has a CUDA FlashAttention kernel.
  #   np            — parallel slots (1 = full context, no KV duplication)
  #   quant         — label surfaced in metadata
  #   mtp           — speculative decoding, see mtpFlags in llama/helpers.nix:
  #                   null | "self" | { file; repo ? hf; nMax ? 2; device ? "igpu"; }
  #   effort        — OpenCode's default reasoning effort (low|medium|high|none)
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
      fitt ? (if mtp == "self" then 1024 else 768),
      fittHeadless ? null,
      kvq ? "q8_0",
      np ? 1,
      quant ? "APEX-I-NanoPlus",
      offloadMMProj ? false,
      effort ? "medium",
      tags ? [ ],
      extra ? [ ],
    }:
    {
      kind = "coder";
      tools = true;
      maxOutput = 32768;
      # hard cap on the thinking phase so a reasoning doom-loop can't eat the context
      reasoningBudget = 16384;
      inherit
        name
        hf
        hfFile
        image
        ctx
        fitCtx
        mtp
        fitt
        fittHeadless
        kvq
        np
        quant
        offloadMMProj
        effort
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
        # Headless has no desktop, so no KWin/Electron to guard against: claim
        # the whole card (no --fit headroom) when there's no one to log in.
        fittHeadless = 0;
      }
      // args
      // {
        tags = [ "dense" ] ++ args.tags or [ ];
      }
    );

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
        tags
        extra
        ;
    };
in
{
  inherit
    model
    valV3
    titleModel
    voiceModel
    ;
}
