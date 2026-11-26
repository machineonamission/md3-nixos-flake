# profiles.nix — services.llama-swap.settings.selectors.
#
# Runtime-switchable model sets (the UI/API "profiles"), NOT the reasoning-effort
# variants (those live in the OpenCode config). Targets must be model ids from
# models.nix; default.nix asserts that at build time.
#
#   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"moe"}'
let
  # warm: keeps targets warm for fast swaps but still lets idle models unload
  profile = name: description: targets: {
    strategy = "warm";
    inherit name description targets;
  };
in
{
  coder = profile "Coder" "Coder GPU Aligned" [
    "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
    "Tiel-Coder-35B-A3B"
  ];

  coder-unsafe = profile "Coder (Unsafe)" "Unsafe/Abliterated Coder GPU" [
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF"
  ];

  coder-mtp = profile "Coder (MTP)" "MTP Speculative Cyber Tiel GPU" [
    "Tiel-Coder-35B-A3B-MTP"
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
  ];

  moe = profile "MoE 35B" "Other 35B-A3B / 29B / Occamy MoE GPU" [
    "Tiel-Coder-35B-A3B"
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF"
    "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF-MTP"
    "Tiel-Coder-35B-A3B-MTP"
    "Ornith-1.5-35B-A3B"
    "MiniCPM-V-4.7-35B-A3B"
    "MiniCPM-V-4.7-35B-A3B-MTP"
    "MiniCPM-V-4.7-35B-A3B-Abliterated"
    "Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF"
    "Occamy-1.0-APEX-I-NanoPlus-V2.1-Abliterated-GGUF"
    "Occamy-1.0"
    "Qwen3.6-35B-A3B-MTP"
  ];

  hybrid = profile "Hybrid Coder" "Dense/Hybrid Qwen3.8-27B Coder GPU" [
    "Qwen3.8-27B-EfficientThink-VAL-APEX-I-NanoPlus-V3-GGUF"
    "Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
    "Arete-27B-VAL-APEX-I-NanoPlus-V3-GGUF"
  ];

  # name/description were a copy-paste of "hybrid"; made distinct
  hybrid-unsafe =
    profile "Hybrid Coder (Unsafe)" "Uncensored/Abliterated Dense/Hybrid Qwen3.8-27B Coder GPU"
      [
        "Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
        "Qwen3.8-27B-TTURBO-709-Uncen-VAL-APEX-I-NanoPlus-V3-GGUF"
        "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-VAL-APEX-I-NanoPlus-V3-GGUF"
      ];

  title = profile "Title" "Title Generation (No Reasoning)" [
    "Qwen3.5-2B"
    "Qwen3.5-0.8B"
  ];
}
