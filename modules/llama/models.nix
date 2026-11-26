# models.nix — every llama-swap model, grouped by the device it runs on.
#
# The top-level keys ARE the routing groups (see default.nix): a model's group
# comes from where you put it, so models and groups can never drift apart.
# The attribute name is the model id that OpenCode and profiles.nix refer to.
#
# Add a model: drop a literal into the right group with only the knobs that
# differ from the defaults documented in helpers.nix.
{
  model,
  valV3,
  titleModel,
}:
{
  # Main coders on the RTX 5070 Ti (CUDA0). One at a time.
  vram = {
    # ---- Tiel 35B-A3B MoE (the main coder) --------------------------------
    "Tiel-Coder-35B-A3B" = model {
      name = "Tiel Coder 35B A3B (NanoPlus)";
      hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
    };

    # The IsValorum quant has no MTP layers, so the draft head comes from another repo.
    "Tiel-Coder-35B-A3B-MTP" = model {
      name = "Tiel Coder 35B A3B (NanoPlus, MTP)";
      hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
      mtp = {
        repo = "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF";
        file = "mtp-Tiel-Coder-35B-A3B.gguf";
      };
    };

    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = model {
      name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
      hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Cyber-Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
    };

    # Same repo ships a separate 1.48 GB draft head.
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP" = model {
      name = "Cyber Tiel 35B A3B (NanoPlus, MTP)";
      hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Cyber-Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
      mtp.file = "mtp-Cyber-Tiel-Coder-35B-A3B.gguf";
    };

    # ---- Qwen3.8-27B VAL-APEX-I-NanoPlus-V3 (dense hybrid, embedded MTP) --
    "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B (VAL-APEX NanoPlus V3)";
      hf = "IsValorum/Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B (Abliterated, VAL-APEX NanoPlus V3)";
      hf = "IsValorum/Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Ships an embedded MTP head AND a dflash sidecar; hfFile avoids the collision.
    "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B EfficientThink (VAL-APEX NanoPlus V3)";
      hf = "IsValorum/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Projector embedded in the GGUF (no separate mmproj file).
    "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B TTURBO-709 Unc (VAL-APEX NanoPlus V3)";
      hf = "IsValorum/Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-TTURBO-709-Uncen.APEX-I-NanoPlus-V3.gguf";
    };

    "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Huihui Qwen3.8 27B Coder390 EfficientThink (VAL-APEX NanoPlus V3, Abliterated)";
      hf = "IsValorum/Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated.VAL-APEX-I-NanoPlus-V3.gguf";
    };

    "Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Swift 1.5 Qwen3.8 27B (VAL-APEX NanoPlus V3, Uncensored)";
      hf = "IsValorum/Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Swift-1.5-Qwen3.8-27B-Uncensored-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Same family but text-only with no MTP head, so a plain `model`.
    "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
      name = "Arete 27B (VAL-APEX NanoPlus V3)";
      hf = "IsValorum/Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Arete-27B-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # ---- APEX-I-NanoPlus: text ---------------------------------------------
    "LFM2.5-24B-A2B" = model {
      name = "LFM2.5 24B A2B (NanoPlus)";
      hf = "IsValorum/LFM2.5-24B-A2B-APEX-I-NanoPlus-GGUF";
      ctx = 131072;
    };

    "Qwen3.8-Flash-Coder" = model {
      name = "Qwen3.8 Flash Coder (NanoPlus)";
      hf = "IsValorum/Qwen3.8-Flash-Coder-APEX-I-NanoPlus-GGUF";
    };

    # No APEX quant exists for Flash Next (~167 GB BF16 MoE). zephel01's L448 is a
    # single quant (clean for bare -hf) tuned for 12 GB VRAM / 32 GB RAM.
    "Qwen3.8-Flash-Next" = model {
      name = "Qwen3.8 Flash Next (L448, 16GB)";
      hf = "zephel01/Qwen3.8-Flash-Next-12G32G-GGUF";
      quant = "L448 (zephel01, 16GB)";
    };

    "Thomson-1.0-Small" = model {
      name = "Thomson 1.0 Small (NanoPlus)";
      hf = "IsValorum/Thomson-1.0-Small-APEX-I-NanoPlus-GGUF";
    };

    # ---- APEX-I-NanoPlus: image --------------------------------------------
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

    # UNVERIFIED: assumes the dspark-* file works as a MiniCPM draft head.
    "MiniCPM-V-4.7-35B-A3B-MTP" = model {
      name = "MiniCPM-V 4.7 35B A3B (NanoPlus, MTP)";
      hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-APEX-I-NanoPlus-GGUF";
      image = true;
      mtp.file = "dspark-MiniCPM-V-4_7-35B-A3B-Q4_K_M.gguf";
    };

    "MiniCPM-V-4.7-35B-A3B-Abliterated" = model {
      name = "MiniCPM-V 4.7 35B A3B (Abliterated)";
      hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-Abliterated-APEX-I-NanoPlus-GGUF";
      image = true;
    };

    "T-Search" = model {
      name = "T-Search (NanoPlus)";
      hf = "IsValorum/T-Search-APEX-I-NanoPlus-GGUF";
      image = true;
    };

    # ---- MoE with MTP --------------------------------------------------------
    "Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF" = model {
      name = "Xing 4.0 29B A4B (APEX-I NanoPlus, Abliterated)";
      hf = "IsValorum/Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF";
      quant = "APEX-I-NanoPlus-Abliterated";
      mtp = "self";
    };

    # Embedded MTP head in blk.40.
    "Qwen3.6-35B-A3B-MTP" = model {
      name = "Qwen3.6 35B A3B MTP (NanoPlus)";
      hf = "IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF";
      image = true;
      mtp = "self";
    };

    "Occamy-1.0" = model {
      name = "Occamy 1.0 (NanoPlus)";
      hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-GGUF";
      hfFile = "Occamy-1.0.APEX-I-NanoPlus.gguf";
      image = true;
      mtp.file = "occamy-1.0-mtp-Q4_K_M.gguf";
    };

    "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF" = model {
      name = "Occamy 1.0 (V2.1 Abliterated)";
      hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF";
      quant = "APEX-I-NanoPlus-V2.1-Abliterated";
      image = true;
      mtp.file = "occamy-1.0-mtp-Q4_K_M.gguf";
    };

    # ---- APEX-I-NanoPlus-V2.1 ------------------------------------------------
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
    };

    "KAT-Coder-V2.5-Dev" = model {
      name = "KAT-Coder V2.5 Dev (V2.1)";
      hf = "IsValorum/KAT-Coder-V2.5-Dev-APEX-I-NanoPlus-V2.1-GGUF";
      hfFile = "KAT-Coder-V2.5-Dev.APEX-I-NanoPlus-V2.1.gguf";
      quant = "APEX-I-NanoPlus-V2.1";
      mtp.file = "mtp-KAT-Coder-V2.5-Dev-Q4_0.gguf";
    };
  };

  # Tiny title models on the Intel iGPU (Vulkan0). Always resident, coexist.
  igpu = {
    "Qwen3.5-2B" = titleModel {
      name = "Qwen3.5-2B iGPU (titles)";
      hf = "unsloth/Qwen3.5-2B-GGUF";
      ctx = 8192;
      reasoningBudget = 512;
      presencePenalty = "1.5";
    };

    "Qwen3.5-0.8B" = titleModel {
      name = "Qwen3.5-0.8B iGPU (titles)";
      hf = "unsloth/Qwen3.5-0.8B-GGUF";
      ctx = 16384;
      reasoningBudget = 256;
      presencePenalty = "2";
    };
  };
}
