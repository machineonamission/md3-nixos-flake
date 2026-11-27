# presets.nix — turn a short model literal (models.nix) into a full spec.
#
# A spec is plain data with every default filled in. It names no backend:
# modules/llama turns it into llama-server flags, modules/opencode into an
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
  #   fitt          — --fit target margin in MiB (embedded MTP heads want 512)
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
      fitt ? (if mtp == "self" then 512 else 256),
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
in
{
  inherit model valV3 titleModel;
}
