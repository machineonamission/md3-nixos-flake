{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Shared llama-server CLI flags — literal conversion of the LLama-GUI
  # "3.6 nano hf.json" preset. No -m file paths; every model loads via -hf.
  #
  # Verified against llama-server --help (v0.6.0):
  #   --checkpoint-min-step   replaces preset's checkpoint-every-n-tokens (renamed in v0.6.0)
  #   --reasoning-effort      replaces preset's chat_template_reasoning_effort
  #   --reasoning-preserve    omitted (boolean flag; default = enabled)
  #   --kv-unified enabled    verified accepted by is_truthy() parser
  #   --reasoning-format auto "auto" is the default enum in common_reasoning_format_from_name()
  #   --fit on                verified: -fit [on|off]
  #   --flash-attn on         verified: -fa [on|off|auto]
  #   --cache-type-k/v        verified: -ctk/-ctv allowed values
  #
  # Preset flags that were dropped (false values or flags not in v0.6.0 CLI):
  #   no_mmproj, mlock, mmap, direct_io, swa_full, preserve_thinking, single_turn,
  #   multiline, context_shift, ngram_* (covered by --spec-type none), no_host,
  #   warmup, offline, spec_draft_adaptive, backend_sampling, tensor_read_lazy,
  #   check_tensors, webui_mcp_proxy, dry_sequence_breakers (empty array)
  #
  # Preset port 9931 → replaced with ${PORT} macro assigned by llama-swap per model.
  default-args = ''
    --image-min-tokens 1024 --image-max-tokens -1 --mtmd-batch-max-tokens 1024
    --ctx-size 262144 --cache-ram 16384
    --batch-size 2048 --ubatch-size 384 --n-predict -1 --keep 0
    --ctx-checkpoints 32 --checkpoint-min-step 2048
    --threads -1 --poll 50
    --load-mode auto
    --gpu-layers auto --main-gpu 0 --gpu-layers-draft auto
    --flash-attn on --kv-offload --repack --op-offload
    --fit on --fit-target 256 --fit-ctx 131072
    --cache-type-k q8_0 --cache-type-v q8_0
    --temperature 0.6 --top-k 20 --top-p 0.95 --min-p 0.05
    --top-n-sigma -1 --typical-p 1
    --repeat-last-n 64 --repeat-penalty 1
    --presence-penalty 0 --frequency-penalty 0
    --dry-multiplier 0.5 --dry-base 1.75 --dry-allowed-length 2 --dry-penalty-last-n -1
    --yarn-orig-ctx 0 --yarn-ext-factor -1 --yarn-attn-factor -1 --yarn-beta-slow -1 --yarn-beta-fast -1
    --reasoning on --reasoning-format auto --reasoning-budget -1 --reasoning-effort high
    --jinja --kv-unified enabled
    --spec-type none
    --host 0.0.0.0 --port ${PORT} --parallel 4
    --cont-batching --cache-prompt --cache-idle-slots --slots
    --timeout 3600 --metrics --webui --embedding
    --slot-prompt-similarity 0.1 --cache-reuse 0
    --verbose --verbosity 4 --log-colors on --log-prefix --log-timestamps --show-timings
    --pooling mean --slot-save-path /home/melody/LLama-GUI/slots
  '';

in
{
  # LLaMA Swap — model swapping for local LLM serving (proxy port 9930)
  # Each model runs the exact llama-server flag set from the LLama-GUI preset,
  # with the -hf HuggingFace repo swapped in.
  services.llama-swap = {
    enable = true;
    port = 9930;

    settings = {
      sendLoadingState = true;
      globalTTL = 0; # never auto-unload (override per-model with ttl: N)
      startPort = 10001; # base for the ${PORT} macro assigned to each model
      logLevel = "info";

      macros = {
        default-args = default-args;
      };

      # -- Models -------------------------------------------------------------
      # Each key is the model ID used in API requests (/v1/chat/completions?model=...)
      models = {
        "qwen36-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF'';
          name = "Qwen3.6 35B A3B MTP APEX-I NanoPlus";
          description = "Qwen3.6-35B calibrated to 13.03 GB (WikiText-2 PPL: 5.5244)";
        };
        "occamy-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Occamy-1.0-APEX-I-NanoPlus-GGUF'';
          name = "Occamy 1.0 APEX-I NanoPlus";
        };
        "ornith-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Ornith-1.5-35B-A3B-APEX-I-NanoPlus-GGUF'';
          name = "Ornith 1.5 35B A3B APEX-I NanoPlus";
        };
        "tiel-coder-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF'';
          name = "Tiel-Coder 35B A3B APEX-I NanoPlus";
        };
        "cyber-tiel-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF'';
          name = "Cyber-Tiel-Coder 35B A3B APEX-I NanoPlus";
        };
        "xing40-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Xing4.0-29B-A4B-APEX-I-NanoPlus-Abliterated-GGUF'';
          name = "Xing4.0 29B A4B APEX-I NanoPlus Abliterated";
        };
        "qwen38-flash-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Qwen3.8-Flash-Coder-APEX-I-NanoPlus-GGUF'';
          name = "Qwen3.8 Flash Coder APEX-I NanoPlus";
        };
        "huihui-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Huihui-Qwen3.8-27B-Abliterated-VAL-APEX-I-NanoPlus-GGUF'';
          name = "Huihui Qwen3.8 27B Abliterated VAL APEX-I NanoPlus";
        };
        "qwen38-eff-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Qwen3.8-27B-EfficientThink-Uncensored-VAL-APEX-I-NanoPlus-GGUF'';
          name = "Qwen3.8 27B EfficientThink Uncensored VAL APEX-I NanoPlus";
        };
        "qwen38-val-nano" = {
          cmd = ''\${default-args} -hf IsValorum/Qwen3.8-27B-VAL-APEX-I-NanoPlus-V3-GGUF'';
          name = "Qwen3.8 27B VAL APEX-I NanoPlus V3";
        };
      };
    };
  };
}
