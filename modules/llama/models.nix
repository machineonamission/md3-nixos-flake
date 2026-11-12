# models.nix — services.llama-swap.settings.models.
#
# Add a model: drop in a `"<id>" = model { ... };` literal with only the knobs
# that differ — all shared flags come from `model` (see helpers.nix). The two
# tiny iGPU title models use `titleModel`.
{
  model,
  titleModel,
  mtpExtra,
  selfMtp,
  ...
}:
{
  # ---- main coding family (35B-A3B, image) --------------------------------
  "Tiel-Coder-35B-A3B" = model {
    name = "Tiel Coder 35B A3B (NanoPlus)";
    hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  # Tiel's own quant disables its baked-in MTP head (nextn_predict_layers=0) —
  # IsValorum's ultra-low-BPW quant makes that head a rough drafter. But the base
  # model it is quantized FROM (peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF) ships its
  # OWN draft head at higher precision, same qwen35moe arch + vocab, so it's
  # architecture-compatible here. Point --spec-draft-model at that base repo:file.
  # Cross-quant experiment — test it, and drop this literal if it loops or helps.
  "Tiel-Coder-35B-A3B-MTP" = model {
    name = "Tiel Coder 35B A3B (NanoPlus, MTP)";
    hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    quant = "APEX-I-NanoPlus";
    image = true;
    mtp =
      hf:
      mtpExtra {
        repo = "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF";
        file = "mtp-Tiel-Coder-35B-A3B.gguf";
      };
  };

  "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = model {
    name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
    hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    image = true;
  };

  # Cyber Tiel NanoPlus ships a SEPARATE draft head in the SAME repo
  # (mtp-Cyber-Tiel-Coder-35B-A3B.gguf, 1.48 GB). This literal reuses the repo
  # with the MTP draft head attached — swap to it at runtime:
  #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"coder-mtp"}'
  "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP" = model {
    name = "Cyber Tiel 35B A3B (NanoPlus, MTP)";
    hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
    quant = "APEX-I-NanoPlus";
    image = true;
    mtp =
      hf:
      mtpExtra {
        repo = hf;
        file = "mtp-Cyber-Tiel-Coder-35B-A3B.gguf";
      };
  };

  # ---- VAL-APEX-I NanoPlus V3 — Qwen3.8 27B dense hybrid -------------------
  # Both ship a Q8_0 mmproj, so offload it to the Intel iGPU like the other
  # image models. Safe (standard) vs abiterated (directional refusal-vector
  # removal over Qwen3.8-27B).
  # Ships a self-contained MTP head (blk.64.*, 15 tensors) in the main GGUF.
  "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B (VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = selfMtp;
  };

  # Ships a self-contained MTP head (blk.64.*, 15 tensors) in the main GGUF.
  "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B (Abliterated, VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = selfMtp;
  };

  # ---- VAL-APEX-I-NanoPlus-V3 (27B dense hybrid) — more variants -----------
  # Same 27B family as the two above; all NanoPlus (~11–13 GB, 16 GB GPUs).
  # EfficientThink / Coder390 / Swift ship a separate mmproj (image); TTURBO is
  # a davidau-style twin-turbo vision model with the projector embedded in the
  # GGUF (no separate mmproj file), so --no-mmproj-offload. Arete is text-only.
  # This repo ships BOTH a self-contained MTP head (blk.64.*) AND a separate
  # speculative/dflash2-*.gguf sidecar. llama.cpp's -hf auto-detects the dflash2
  # sidecar and tries to load it as the draft, but the dflash2 sidecar has no
  # lm_head and needs ctx_other wired to the target context — v0.5.0's load path
  # dies on "dflash requires ctx_other to be set" and the model never comes up.
  # Requesting draft-mtp (selfMtp) makes llama.cpp use the integrated MTP head
  # AND stop auto-picking the dflash sidecar, which fixes the crash.
  "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B EfficientThink (VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = selfMtp;
  };

  # Ships a self-contained MTP head (blk.64.*, 15 tensors) in the main GGUF.
  "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Qwen3.8 27B TTURBO-709 Unc (VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = selfMtp;
  };

  "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Arete 27B (VAL-APEX NanoPlus V3)";
    hf = "IsValorum/Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
  };

  # Ships a self-contained MTP head (blk.64.*, 15 tensors) in the main GGUF.
  "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Huihui Qwen3.8 27B Coder390 EfficientThink (VAL-APEX NanoPlus V3, Abliterated)";
    hf = "IsValorum/Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512; # higher fan-in for the self-contained MTP head
    extra = selfMtp;
  };

  # Swift-1.5 is self-contained MTP (the MTP head lives in blk, like Qwen3.6-35B-
  # A3B-MTP) — no separate draft file, so it uses the raw spec flags + higher
  # fan-in for the head.
  "Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
    name = "Swift 1.5 Qwen3.8 27B (VAL-APEX NanoPlus V3, Uncensored)";
    hf = "IsValorum/Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF";
    quant = "VAL-APEX-I-NanoPlus-V3";
    image = true;
    fitt = 512;
    extra = selfMtp;
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

  # IsValorum ships separate draft heads for the 35B-A3B family (Cyber Tiel,
  # Occamy). These `dspark-*` files are the MiniCPM drafts (base openbmb release
  # ships none), same arch/vocab, so they load here as the MTP drafter. Q4_K_M
  # is the light draft. UNVERIFIED file meaning — if it fails to load as a draft,
  # drop this literal.
  "MiniCPM-V-4.7-35B-A3B-MTP" = model {
    name = "MiniCPM-V 4.7 35B A3B (NanoPlus, MTP)";
    hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-APEX-I-NanoPlus-GGUF";
    quant = "APEX-I-NanoPlus";
    image = true;
    mtp =
      hf:
      mtpExtra {
        repo = hf;
        file = "dspark-MiniCPM-V-4_7-35B-A3B-Q4_K_M.gguf";
      };
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

  # ---- APEX-I-NanoPlus — Abliterated (MoE) --------------------------------
  # Smaller / abiterated variants that still fit a 16 GB GPU. Occamy-V2.1-Abliterated
  # ships a separate draft head in its own repo (see Occamy-1.0 below for the knob).
  "Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF" = model {
    name = "Xing 4.0 29B A4B (APEX-I NanoPlus, Abliterated)";
    hf = "IsValorum/Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF";
    quant = "APEX-I-NanoPlus-Abliterated";
    # text-only; has the "mtp" tag but no separate draft file — self-contained
  };

  "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF" = model {
    name = "Occamy 1.0 (V2.1 Abliterated)";
    hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF";
    quant = "APEX-I-NanoPlus-V2.1-Abliterated";
    image = true; # separate mmproj-Q8_0.gguf
    mtp =
      hf:
      mtpExtra {
        repo = hf;
        file = "occamy-1.0-mtp-Q4_K_M.gguf";
      };
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
    extra = selfMtp;
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
