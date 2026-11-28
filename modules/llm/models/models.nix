# models.nix — every model, grouped by the device it runs on.
#
# The top-level keys ARE the llama-swap routing groups (see llama/default.nix):
# a model's group comes from where you put it, so models and groups can never
# drift apart. The attribute name is the model id llama-swap serves, OpenCode
# lists, and profiles.nix refers to.
#
# Add a model: drop a literal into the right group with only the knobs that
# differ from the defaults documented in presets.nix, and give it `tags` so
# the profiles in profiles.nix that match on them pick it up automatically.
# Derived tags (kind, group, mtp, image, nanoplus) are added for you.
{
  model,
  valV3,
  flashNext,
  tieredModel,
  titleModel,
  voiceModel,
}:
{
  # CPU-only models (claim no VRAM, so they never evict anything). Only the HA
  # voice fallback lives here; see the `voice` selector in profiles.nix.
  cpu = {
    # Picked 2026-11-27 with home-assistant-server/voice/eval.py (the live HA
    # Assist prompt + 50 tools, 15 utterances, first-round tool calls graded):
    #   Qwen3.5-4B  Q4_K_M  15/15  ~3.5 s/round warm, 11 t/s gen, 140 t/s prefill
    #   Qwen3.5-9B  Q4_K_M  13/15  ~1.5x slower
    #   gemma-4-E4B Q4_K_M   8/15  fast, but often emits tool calls as plain text
    #   Qwen3.5-2B (title)  "isn't cutting it" (user), 9 t/s on the busy iGPU
    # Cold prefill of the ~7.8k-token prompt is ~65 s; HA primes it when
    # llama-swap comes up (automation "Voice: pick pipeline").
    "voice-Qwen3.5-4B" = voiceModel {
      name = "Qwen3.5 4B CPU (HA voice)";
      hf = "unsloth/Qwen3.5-4B-GGUF:Q4_K_M";
    };
  };

  # Models on the RTX 5070 Ti (CUDA0). Coders claim the whole card: one at a time.
  vram = {
    # HA voice on the RTX while no coder holds it: first target of the `voice`
    # selector, loaded on demand (cold start ~4 s load + ~2.5 s prefill from the
    # local HF cache), unloaded after 600 s idle, evicted by any coder.
    # Picked 2026-11-27 with home-assistant-server/voice/bench.py (3 reps, prompt
    # with the 4 extra rules; hard set = args checked, 75 cases):
    #   gemma-4-12b Q4_K_M      hard 71/75  0.42 s/turn  7.9 GB   <- this
    #   gemma-4-26B-A4B MoE     hard 69/75  0.35 s/turn  12 GB    "lights off" -> HassLightSet
    #   Qwen3.5-4B              hard 67/75  0.24 s/turn  3.5 GB   the previous pick
    #   Inkling-2-Mini MoE      21/25 (1 rep), 1.5 s/turn, 12 GB; garbage with -rea off
    #   LFM2.5-24B-A2B MoE      hard 41/75  0.15 s/turn  11 GB    locks on "unlock"
    # Thinking on (effort low) made every model worse: gemma 69/75 with 13 s p90
    # (multi-action turns burn 2k tokens and return nothing), Qwen 4B/9B start
    # answering trivia and pick the opposite light script. Keep -rea off.
    "voice-gpu-gemma-4-12b" = voiceModel {
      name = "Gemma 4 12B GPU (HA voice)";
      hf = "unsloth/gemma-4-12b-it-GGUF:Q4_K_M";
      device = "cuda";
      vramMiB = 8200; # measured 7920 MiB at 16k ctx
      ttl = 600;
    };

    # ---- Tiel 35B-A3B MoE (the main coder) --------------------------------
    "Tiel-Coder-35B-A3B" = model {
      name = "Tiel Coder 35B A3B (NanoPlus)";
      tags = [
        "tiel"
        "moe"
      ];
      hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
    };

    # The IsValorum quant has no MTP layers, so the draft head comes from another repo.
    "Tiel-Coder-35B-A3B-MTP" = model {
      name = "Tiel Coder 35B A3B (NanoPlus, MTP)";
      tags = [
        "tiel"
        "moe"
      ];
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
      tags = [
        "tiel"
        "moe"
        "unsafe"
      ];
      hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Cyber-Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
    };

    # Same repo ships a separate 1.48 GB draft head.
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP" = model {
      name = "Cyber Tiel 35B A3B (NanoPlus, MTP)";
      tags = [
        "tiel"
        "moe"
        "unsafe"
      ];
      hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
      hfFile = "Cyber-Tiel-Coder-35B-A3B.APEX-I-NanoPlus.gguf";
      image = true;
      mtp.file = "mtp-Cyber-Tiel-Coder-35B-A3B.gguf";
    };

    # ---- Qwen3.8-27B VAL-APEX-I-NanoPlus-V3 (dense hybrid, embedded MTP) --
    "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B (VAL-APEX NanoPlus V3)";
      tags = [ "qwen3.8" ];
      hf = "IsValorum/Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B (Abliterated, VAL-APEX NanoPlus V3)";
      # DAU reasoning template: accepts low|medium|xhigh (rejects "high")
      efforts = [
        "low"
        "medium"
        "xhigh"
      ];
      tags = [
        "qwen3.8"
        "unsafe"
      ];
      hf = "IsValorum/Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Ships an embedded MTP head AND a dflash sidecar; hfFile avoids the collision.
    "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B EfficientThink (VAL-APEX NanoPlus V3)";
      # DAU reasoning template: accepts low|medium|xhigh (rejects "high")
      efforts = [
        "low"
        "medium"
        "xhigh"
      ];
      tags = [ "qwen3.8" ];
      hf = "IsValorum/Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Projector embedded in the GGUF (no separate mmproj file).
    "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Qwen3.8 27B TTURBO-709 Unc (VAL-APEX NanoPlus V3)";
      # DAU reasoning template: accepts low|medium|xhigh (rejects "high")
      efforts = [
        "low"
        "medium"
        "xhigh"
      ];
      tags = [
        "qwen3.8"
        "unsafe"
      ];
      hf = "IsValorum/Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Qwen3.8-27B-TTURBO-709-Uncen.APEX-I-NanoPlus-V3.gguf";
    };

    "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Huihui Qwen3.8 27B Coder390 EfficientThink (VAL-APEX NanoPlus V3, Abliterated)";
      # DAU reasoning template: accepts low|medium|xhigh (rejects "high")
      efforts = [
        "low"
        "medium"
        "xhigh"
      ];
      tags = [
        "qwen3.8"
        "unsafe"
      ];
      hf = "IsValorum/Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated.VAL-APEX-I-NanoPlus-V3.gguf";
    };

    "Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF" = valV3 {
      name = "Swift 1.5 Qwen3.8 27B (VAL-APEX NanoPlus V3, Uncensored)";
      tags = [
        "qwen3.8"
        "unsafe"
      ];
      hf = "IsValorum/Swift-1.5-Qwen3.8-27B-Uncensored-MTP-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Swift-1.5-Qwen3.8-27B-Uncensored-VAL-APEX-I-NanoPlus-V3.gguf";
    };

    # Same family but text-only with no MTP head, so a plain `model`.
    # ctx pinned to the family's 131072 (the plain preset defaults to 262144,
    # which would overstate the window in OpenCode).
    "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF" = model {
      name = "Arete 27B (VAL-APEX NanoPlus V3)";
      tags = [
        "qwen3.8"
        "dense"
      ];
      hf = "IsValorum/Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF";
      hfFile = "Arete-27B-VAL-APEX-I-NanoPlus-V3.gguf";
      ctx = 131072;
    };

    # ---- APEX-I-NanoPlus: text ---------------------------------------------
    "LFM2.5-24B-A2B" = model {
      name = "LFM2.5 24B A2B (NanoPlus)";
      tags = [ "lfm" ];
      hf = "IsValorum/LFM2.5-24B-A2B-APEX-I-NanoPlus-GGUF";
      ctx = 131072;
    };

    "Qwen3.8-Flash-Coder" = flashNext {
      name = "Qwen3.8 Flash Coder (NanoPlus)";
      hf = "IsValorum/Qwen3.8-Flash-Coder-APEX-I-NanoPlus-GGUF";
    };

    # No APEX quant exists for Flash Next (~167 GB BF16 MoE). zephel01's L448 is a
    # single quant (clean for bare -hf) tuned for 12 GB VRAM / 32 GB RAM.
    "Qwen3.8-Flash-Next" = flashNext {
      name = "Qwen3.8 Flash Next (L448, 16GB)";
      hf = "zephel01/Qwen3.8-Flash-Next-12G32G-GGUF";
      quant = "L448 (zephel01, 16GB)";
    };

    # The ruriww/llama.cpp fork's tiered build of Flash Next: 512 experts, ~94 GiB,
    # streamed from the NVMe around a VRAM expert cache. Files in
    # /var/lib/llm-models/flash-next (llama-swap/helpers.nix rubyModelDir):
    #   flash-next.gguf     = rev4_rbf_m48_a8_a1u7x64.gguf
    #   flash-next-mtp.gguf = mtp-i2trn-t0.gguf
    "Qwen3.8-Flash-Next-Tiered" = tieredModel {
      name = "Qwen3.8 Flash Next (tiered, ruby fork)";
      quant = "rev4_rbf_m48_a8_a1u7x64 (trellis tiers)";
      tags = [ "qwen3.8-flash" ];
    };

    "Thomson-1.0-Small" = model {
      name = "Thomson 1.0 Small (NanoPlus)";
      hf = "IsValorum/Thomson-1.0-Small-APEX-I-NanoPlus-GGUF";
    };

    # ---- APEX-I-NanoPlus: image --------------------------------------------
    "Ornith-1.5-35B-A3B" = model {
      name = "Ornith 1.5 35B A3B (NanoPlus)";
      tags = [ "moe" ];
      hf = "IsValorum/Ornith-1.5-35B-A3B-APEX-I-NanoPlus-GGUF";
      image = true;
    };

    "MiniCPM-V-4.7-35B-A3B" = model {
      name = "MiniCPM-V 4.7 35B A3B (NanoPlus)";
      tags = [
        "minicpm"
        "moe"
      ];
      hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-APEX-I-NanoPlus-GGUF";
      image = true;
    };

    # UNVERIFIED: assumes the dspark-* file works as a MiniCPM draft head.
    "MiniCPM-V-4.7-35B-A3B-MTP" = model {
      name = "MiniCPM-V 4.7 35B A3B (NanoPlus, MTP)";
      tags = [
        "minicpm"
        "moe"
      ];
      hf = "IsValorum/MiniCPM-V-4.7-35B-A3B-APEX-I-NanoPlus-GGUF";
      image = true;
      mtp.file = "dspark-MiniCPM-V-4_7-35B-A3B-Q4_K_M.gguf";
    };

    "MiniCPM-V-4.7-35B-A3B-Abliterated" = model {
      name = "MiniCPM-V 4.7 35B A3B (Abliterated)";
      tags = [
        "minicpm"
        "moe"
        "unsafe"
      ];
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
      tags = [
        "xing"
        "moe"
        "unsafe"
      ];
      hf = "IsValorum/Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF";
      quant = "APEX-I-NanoPlus-Abliterated";
      mtp = "self";
    };

    # Embedded MTP head in blk.40.
    "Qwen3.6-35B-A3B-MTP" = model {
      name = "Qwen3.6 35B A3B MTP (NanoPlus)";
      tags = [
        "qwen3.6"
        "moe"
      ];
      hf = "IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF";
      image = true;
      mtp = "self";
    };

    "Occamy-1.0" = model {
      name = "Occamy 1.0 (NanoPlus)";
      tags = [
        "occamy"
        "moe"
      ];
      hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-GGUF";
      hfFile = "Occamy-1.0.APEX-I-NanoPlus.gguf";
      image = true;
      mtp.file = "occamy-1.0-mtp-Q4_K_M.gguf";
    };

    "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF" = model {
      name = "Occamy 1.0 (V2.1 Abliterated)";
      tags = [
        "occamy"
        "moe"
        "unsafe"
      ];
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

  # Tiny title models on the Intel iGPU (Vulkan0). Claim no VRAM, coexist, ttl 120 s.
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
