# models.nix — services.llama-swap.settings.models.
#
# Add a model: drop in a `"<id>" = model { ... };` literal with only the knobs
# that differ — all shared flags come from `model` (see helpers.nix). The two
# tiny iGPU title models use `titleModel`.
{
  model,
  titleModel,
  mtpExtra,
  ...
}:
{
  # ---- main coding family (35B-A3B, image) --------------------------------
  "Tiel-Coder-35B-A3B" = model {
    name = "Tiel Coder 35B A3B (NanoPlus)";
    hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = model {
    name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
    hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  # ---- VAL-APEX-I NanoPlus V3 — Qwen3.8 27B dense hybrid -------------------
  # Both ship a Q8_0 mmproj, so offload it to the Intel iGPU like the other
  # image models. Safe (standard) vs abiterated (directional refusal-vector
  # removal over Qwen3.8-27B).
  "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B (VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
  };

  "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B (Abliterated, VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
  };

  # ---- APEX-I-NanoPlus collection: text models ----------------------------
  "LFM2.5-24B-A2B" = model {
    name = "LFM2.5 24B A2B (NanoPlus)";
    hf = "IsValorum/LFM2.5-24B-A2B-APEX-I-NanoPlus-GGUF";
    ctx = 131072; # text-only (no mmproj); smaller 128K context window
  };

  "Qwen3.8-Flash-Coder" = model {
    name = "Qwen3.8 Flash Coder (NanoPlus)";
    hf = "IsValorum/Qwen3.8-Flash-Coder-APEX-I-NanoPlus-GGUF";
    # text-only, qwen4exp architecture
  };

  # ---- Flash Next — 16 GB VRAM quant (no IsValorum APEX quant) ------------
  # IsValorum only ships "Flash Coder", NOT "Flash Next", so there's no APEX
  # quant for it. The base Qwen3.8-Flash-Next is a huge ~167 GB BF16 qwen4_exp
  # MoE, so I picked the best low-VRAM fit instead:
  #   * zephel01's L448 quant is a SINGLE quant (3 shards) — clean for -hf.
  #     The popular repos (bartowski/unsloth/ISTA) ship dozens of quants and
  #     break bare -hf, so they're out.
  #   * built for a 12 GB VRAM / 32 GB RAM machine → ideal for the 16 GB dGPU
  #     with heavy CPU offload.
  #   * repo ships NO mmproj, so this is text-only here.
  "Qwen3.8-Flash-Next" = model {
    name = "Qwen3.8 Flash Next (L448, 16GB)";
    hf = "zephel01/Qwen3.8-Flash-Next-12G32G-GGUF";
    quant = "L448 (zephel01, 16GB)";
  };

  "Thomson-1.0-Small" = model {
    name = "Thomson 1.0 Small (NanoPlus)";
    hf = "IsValorum/Thomson-1.0-Small-APEX-I-NanoPlus-GGUF";
    # text-only
  };

  # ---- APEX-I-NanoPlus collection: image models ---------------------------
  "Ornith-1.5-35B-A3B" = model {
    name = "Ornith 1.5 35B A3B (NanoPlus)";
    hf = "IsValorum/Ornith-1.5-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  "MiniCPM-V-4.7-35B-A3B" = model {
    name = "MiniCPM-V 4.7 35B A3B (NanoPlus)";
    hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  "MiniCPM-V-4.7-35B-A3B-Abliterated" = model {
    name = "MiniCPM-V 4.7 35B A3B (Abliterated)";
    hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-Abliterated-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  "T-Search" = model {
    name = "T-Search (NanoPlus)";
    hf = "IsValorum/T-Search-APEX-I-NanoPlus-GGUF";
    # multimodal search model (has mmproj + `multimodal` tag)
    image = true;
  };

  # ---- APEX-I-NanoPlus-V2.1 collection ------------------------------------
  "Sage-A1.5" = model {
    name = "Sage-A1.5 (V2.1)";
    hf = "IsValorum/Sage-A1.5-APEX-I-NanoPlus-V2.1-GGUF";
    quant = "APEX-I-NanoPlus-V2.1";
    image = true;
  };

  "Flint" = model {
    name = "Flint (V2.1)";
    hf = "IsValorum/Flint-APEX-I-NanoPlus-V2.1-GGUF";
    quant = "APEX-I-NanoPlus-V2.1";
    # text-only
  };

  # ---- APEX-I-NanoPlus-V2.1: MTP with a SEPARATE draft head ---------------
  # KAT documents the knob as --draft-max (vs Occamy's --spec-draft-n-max).
  "KAT-Coder-V2.5-Dev" = model {
    name = "KAT-Coder V2.5 Dev (V2.1)";
    hf = "IsValorum/KAT-Coder-V2.5-Dev-APEX-I-NanoPlus-V2.1-GGUF";
    quant = "APEX-I-NanoPlus-V2.1";
    # text-only; MTP uses a separate standalone draft head in the same repo,
    # targeted with `repo:file` (llama.cpp HF file targeting).
    mtp =
      hf:
      mtpExtra {
        repo = hf;
        file = "mtp-KAT-Coder-V2.5-Dev-Q4_0.gguf";
        draftMax = 2;
      };
  };

  # ---- APEX-I-NanoPlus: MTP with a SEPARATE draft head --------------------
  "Occamy-1.0" = model {
    name = "Occamy 1.0 (NanoPlus)";
    hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-GGUF";
    image = true;
    # MTP uses a separate standalone draft head in the same repo, targeted with
    # `repo:file`. Occamy documents the knob as --spec-draft-n-max.
    mtp =
      hf:
      mtpExtra {
        repo = hf;
        file = "occamy-1.0-mtp-Q4_K_M.gguf";
      };
  };

  # ---- MTP model (self-contained speculative decode) ----------------------
  # IsValorum/Qwen3.6-35B-A3B-MTP is a SELF-CONTAINED MTP model: the MTP head is
  # integrated into blk.40 inside the SAME file (no separate --model-draft).
  # Same 35B-A3B/qwen35moe family as Tiel, so it reuses baseCmd; only the spec
  # flags differ from `--spec-type none`. Swap to it at runtime:
  #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"mtp"}'
  "Qwen3.6-35B-A3B-MTP" = model {
    name = "Qwen3.6 35B A3B MTP (NanoPlus)";
    hf = "IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = [
      "--spec-type"
      "draft-mtp"
      "--spec-draft-n-max"
      "2"
      "--spec-draft-p-min"
      "0.6"
    ];
  };

  # ---- tiny iGPU title models ---------------------------------------------
  # These live in the routing group's `members` and are unloaded after 120s
  # idle (see titleModel in helpers.nix) so they don't stay resident and hog
  # RAM. They differ only in repo / context / reasoning budget / penalty.
  "Qwen3.5-2B" = titleModel {
    name = "Qwen3.5-2B iGPU (titles)";
    hf = "unsloth/Qwen3.5-2B-GGUF";
    ctx = 8192;
    reasoningBudget = 512;
    presencePenalty = "1.5"; # string, not a number — see titleModel note
  };

  "Qwen3.5-0.8B" = titleModel {
    name = "Qwen3.5-0.8B iGPU (titles)";
    hf = "unsloth/Qwen3.5-0.8B-GGUF";
    ctx = 16384;
    reasoningBudget = 256;
    presencePenalty = "2"; # string, not a number — see titleModel note
  };
}
