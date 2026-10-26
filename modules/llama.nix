{
  config,
  pkgs,
  lib,
  inputs,
  pkgs-llama,
  ...
}:
{
  # LLaMA C++ CUDA build from source (uses nixpkgs-unstable with cudaSupport)
  environment.systemPackages = with pkgs-llama; [
    llama-cpp-cuda
    llama-swap
  ];

  # LLaMA Swap — model swapping for local LLM serving.
  #   llama-swap listens on 9930 (the OpenAI-compatible front door)
  #   and spawns llama-server on ${PORT} (the ${PORT} macro starts here).
  #
  # HOW THE MODULE WORKS (this answers "am I doing it wrong"):
  #   `services.llama-swap.settings` is a FREEFORM YAML value. The module
  #   serialises it to config.yaml and runs `llama-swap -validate` at build
  #   time (options.services.llama-swap.validateConfigFile, default true).
  #   That validator checks it against config-schema.json automatically.
  #
  #   So you do NOT hand-translate the whole JSON schema into Nix. You just
  #   add the fields you care about and let the validator catch typos / wrong
  #   types at `nix build` time. The schema is a checklist, not a template to
  #   fill in wholesale. If you want, write the config in YAML first, validate
  #   it with `llama-swap -validate -config <file>`, then convert it here —
  #   that's the "automatic" round-trip.
  #
  # "REASONING PROFILES" in llama-swap are two separate features:
  #   * setParamsByID  -> reasoning_effort variants (:high/:low) created as
  #                        aliases WITHOUT reloading the model. Works now with
  #                        a single model. This is the practical "profile".
  #   * profiles        -> runtime-selectable model-ID rewrites, switched via
  #                        the UI/API (or hooks.on_startup.profile). Genuinely
  #                        useful only once you have more than one model.
  services.llama-swap =
    let
      # Unified CUDA + Vulkan build. pkgs-llama was imported with cudaSupport
      # only (llama-cpp-cuda), which can only talk to the NVIDIA dGPU. Overriding
      # both flags produces one binary that sees BOTH devices:
      #   * CUDA  -> NVIDIA RTX 5070 Ti  (the fast card, holds the model weights)
      #   * Vulkan-> Intel Graphics RPL-S (the iGPU, holds only the small mmproj)
      # We keep the heavy model on CUDA and offload ONLY the mmproj to the iGPU
      # (the iGPU is slow integrated graphics — putting model layers there would
      # tank generation speed).
      llama-cpp = pkgs-llama.llama-cpp.override {
        cudaSupport = true;
        vulkanSupport = true;
      };
      llama-server = lib.getExe' llama-cpp "llama-server";
    in
    {
      enable = true;
      port = 9930; # llama-swap front door
      # startPort = 5800; # default; ${PORT} starts here -> llama-server
      listenAddress = "0.0.0.0"; # allow other devices to access webui lol
      settings = {
        # ---- global settings ------------------------------------------------
        # healthCheckTimeout is in SECONDS (schema min 15, default 120).
        # 500 is fine for a big model that takes a while to load.
        healthCheckTimeout = 500;
        sendLoadingState = true; # inject loading updates into the reasoning field

        # includeAliasesInList pushes the reasoning-effort variants (:high/:low/:medium)
        # into /v1/models. Without it, llama-swap only lists the base model ID and
        # OpenCode's model discovery can't see the variants even though they route
        # and apply reasoning_effort fine. This is what makes them selectable in @opencode.
        includeAliasesInList = true;

        # ---- models ---------------------------------------------------------
        models = {
          "Tiel-Coder-35B-A3B" = {
            name = "Tiel Coder 35B A3B (NanoPlus)";

            # experiment: offload to igpu. igpu is observed to actually process, but the model always reports its "garbled".
            # --mmproj-offload --mmproj-device Vulkan0
            cmd =
              "${llama-server} "
              +
                # llama-swap swaps the PORT macro for the model's runtime port
                "--port \${PORT} "
              +
                # remote HF GGUF model (APEX-I NanoPlus quant)
                "-hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF "
              +
                # image projection minimum tokens
                "--image-min-tokens 1024 "
              +
                # context size (tokens)
                "-c 262144 "
              +
                # batch size
                "-b 2048 "
              +
                # unified batch
                "-ub 512 "
              +
                # automatic load mode (GGUF load-alternative heuristics)
                "--load-mode auto "
              +
                # context memory (MiB)
                "-cram 16384 "
              +
                # context memory slots
                "-cms 2048 "
              +
                # health poll interval (ms)
                "--poll 50 "
              +
                # layers offloaded to GPU (auto = as many as fit)
                "-ngl auto "
              +
                # GPU index
                "-mg 0 "
              +
                # flash attention
                "-fa on "
              +
                # KV cache optimization
                "-kvo "
              +
                # repack weights for the target quant
                "--repack "
              +
                # offload image projectors
                "--op-offload "
              +
                # fan-in scale (mamba)
                "-fit on "
              +
                # fan-in iterations
                "-fitt 1024 "
              +
                # fan-in channels
                "-fitc 131072 "
              +
                # do NOT offload projectors to the iGPU (Tiel keeps mmproj on CUDA)
                "--no-mmproj-offload "
              +
                # sampling temperature
                "--temp 0.6 "
              +
                # top-k sampling
                "--top-k 20 "
              +
                # top-p (nucleus) sampling
                "--top-p 0.95 "
              +
                # min-p sampling
                "--min-p 0.0 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0 "
              +
                # reasoning effort on
                "-rea on "
              +
                # jinja chat template
                "--jinja "
              +
                # context key quantization
                "-ctk q8_0 "
              +
                # context value quantization
                "-ctv q8_0 "
              +
                # unified KV cache across modalities
                "--kv-unified "
              +
                # speculative decoding type (none = pure greedy)
                "--spec-type none "
              +
                # bind address
                "--host 0.0.0.0 "
              +
                # max number of parallel requests
                "-np 3 "
              +
                # continuous batching
                "-cb "
              +
                # cache prompt embeddings
                "--cache-prompt "
              +
                # cache idle model slots
                "--cache-idle-slots "
              +
                # number of model slots
                "--slots "
              +
                # idle unload timeout (ms)
                "-to 3600 "
              +
                # HTTP worker threads (-1 = auto)
                "--threads-http -1 "
              +
                # expose metrics endpoint
                "--metrics "
              +
                # enable the web UI
                "--webui "
              +
                # dense embedding model
                "--embedding "
              +
                # special-token penalty scale
                "-sps 0.1 "
              +
                # verbose logging
                "-v "
              +
                # log verbosity level
                "-lv 4 "
              +
                # colorize log output
                "--log-colors on "
              +
                # prefix each log line with its source
                "--log-prefix "
              +
                # include timestamps in logs
                "--log-timestamps "
              +
                # skip the warmup prefill
                "--no-warmup "
              +
                # max accepted length for speculative (dry) decoding
                "--dry-allowed-length 150 "
              +
                # speculative decoding multiplier
                "--dry-multiplier 0.4 "
              +
                # speculative decoding base
                "--dry-base 1.75 "
              +
                # speculative decoding last-n penalty
                "--dry-penalty-last-n 2000 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0";

            # Where llama-swap routes API requests. Defaults to
            # http://localhost:${PORT}; written here explicitly.
            # proxy = "http://localhost:\${PORT}";
            checkEndpoint = "/health"; # default; set to "none" to skip health check

            # What modalities this model exposes (used in /v1/models).
            # Fields left out are auto-filled from the upstream server.
            capabilities = {
              "in" = [
                "text"
                "image"
              ];
              out = [
                "text"
              ];
              tools = true;
              context = 262144;
            };

            # ---- reasoning profiles (no reload) ----
            # Explicit aliases so the variants show up in /v1/models (needs the
            # includeAliasesInList above). setParamsByID below then sets
            # reasoning_effort per variant — llama-swap sees these already exist
            # as aliases and just layers the param override on top, no conflict.
            # OpenCode then sees llama-swap/Tiel-Coder-35B-A3B:high/:low/:medium.
            aliases = [
              "\${MODEL_ID}#high"
              "\${MODEL_ID}#low"
              "\${MODEL_ID}#medium"
            ];

            # ---- reasoning profiles (no reload) ----
            # setParamsByID sets request-body params based on which model ID
            # (or alias) the client requested. It auto-creates an alias for each
            # key, so `Tiel-Coder-35B-A3B#high` selects reasoning_effort: high
            # without reloading. Protected params like "model" can't be changed.
            #
            # CRITICAL: this MUST live under `filters`. llama-swap only reads
            # filters.setParamsByID (internal/config/load.go). Left at the model
            # top level it is silently ignored — the schema validator can't catch
            # it either — which is exactly why the variants showed "No reasoning".
            # The aliases array below is redundant (setParamsByID auto-registers
            # them), but harmless and kept for /v1/models clarity.
            filters = {
              setParamsByID = {
                "\${MODEL_ID}#medium" = {
                  chat_template_kwargs = {
                    reasoning_effort = "medium";
                  };
                };
                "\${MODEL_ID}#high" = {
                  chat_template_kwargs = {
                    reasoning_effort = "high";
                  };
                };
                "\${MODEL_ID}#low" = {
                  chat_template_kwargs = {
                    reasoning_effort = "low";
                  };
                };
              };
            };

            # concurrencyLimit = 0; # 0 = internal default of 10
            # ttl = 0; # 0 = never auto-unload; -1 = use global globalTTL
          };

          # ---- SINGLE-SLOT / FULL-CONTEXT MODE --------------------------------
          # Same 35B-A3B weights as the model above, but run with ONE server
          # slot so the ENTIRE 256k KV pool belongs to whichever single sequence
          # is generating. Other chats queue in llama.cpp's internal ring buffer
          # and are served one at a time (continuous batching still speeds up
          # prompt prefill). This is the "as many full-context chats as you
          # want, but slower" mode.
          #
          # HOW TO USE IT:
          #   * Switch to it at runtime (no rebuild) via the OpenCode model
          #     selector, or:
          #       curl -X PUT localhost:9930/api/profiles/active \
          #            -d '{"name":"full-context"}'
          #   * The startup default is set by hooks.on_startup.profile below.
          #
          # THE ONE FLAG THAT MATTERS:
          #   * -np 1  -> ONE parallel slot. This is what gives the single
          #               sequence the full 256k context window.
          #   * NOTE "--slots" does NOT do this — "--slots" only toggles the
          #               /slots HTTP monitoring endpoint. The parallel-slot
          #               count is -np/--parallel (see the model above uses -np 3).
          #   * --kvu  -> unified KV pool, so with -np 1 the whole pool is one
          #               slot (no per-slot split).
          #
          # WHY concurrencyLimit IS HIGHER HERE:
          #   * llama-swap's per-model concurrencyLimit defaults to 10 and
          #     REJECTS (HTTP 429) anything past it rather than queueing. Bumping
          #     it lets more full-context chats line up. They still generate one
          #     at a time (-np 1); this just raises the queue ceiling.
          "Tiel-Coder-35B-A3B-HighContext" = {
            name = "Tiel Coder 35B A3B (Single Slot — Full Context)";
            cmd =
              "${llama-server} "
              +
                # llama-swap swaps the PORT macro for the model's runtime port
                "--port \${PORT} "
              +
                # remote HF GGUF model (APEX-I NanoPlus quant — SAME weights as above)
                "-hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF "
              +
                # image projection minimum tokens
                "--image-min-tokens 1024 "
              +
                # context size (tokens)
                "-c 262144 "
              +
                # batch size
                "-b 2048 "
              +
                # unified batch
                "-ub 512 "
              +
                # automatic load mode (GGUF load-alternative heuristics)
                "--load-mode auto "
              +
                # context memory (MiB)
                "-cram 16384 "
              +
                # context memory slots
                "-cms 2048 "
              +
                # health poll interval (ms)
                "--poll 50 "
              +
                # layers offloaded to GPU (auto = as many as fit)
                "-ngl auto "
              +
                # GPU index
                "-mg 0 "
              +
                # flash attention
                "-fa on "
              +
                # KV cache optimization
                "-kvo "
              +
                # repack weights for the target quant
                "--repack "
              +
                # offload image projectors
                "--op-offload "
              +
                # fan-in scale (mamba)
                "-fit on "
              +
                # fan-in iterations
                "-fitt 1024 "
              +
                # fan-in channels
                "-fitc 131072 "
              +
                # do NOT offload projectors to the iGPU (Tiel keeps mmproj on CUDA)
                "--no-mmproj-offload "
              +
                # sampling temperature
                "--temp 0.6 "
              +
                # top-k sampling
                "--top-k 20 "
              +
                # top-p (nucleus) sampling
                "--top-p 0.95 "
              +
                # min-p sampling
                "--min-p 0.0 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0 "
              +
                # reasoning effort on
                "-rea on "
              +
                # jinja chat template
                "--jinja "
              +
                # context key quantization
                "-ctk q8_0 "
              +
                # context value quantization
                "-ctv q8_0 "
              +
                # unified KV cache across modalities
                "--kv-unified "
              +
                # speculative decoding type (none = pure greedy)
                "--spec-type none "
              +
                # bind address
                "--host 0.0.0.0 "
              +
                # ONE parallel slot: the full 256k context belongs to the one
                # active sequence; other chats queue and are served one at a time.
                "-np 1 "
              +
                # continuous batching
                "-cb "
              +
                # cache prompt embeddings
                "--cache-prompt "
              +
                # cache idle model slots
                "--cache-idle-slots "
              +
                # number of model slots
                "--slots "
              +
                # idle unload timeout (ms)
                "-to 3600 "
              +
                # HTTP worker threads (-1 = auto)
                "--threads-http -1 "
              +
                # expose metrics endpoint
                "--metrics "
              +
                # enable the web UI
                "--webui "
              +
                # dense embedding model
                "--embedding "
              +
                # special-token penalty scale
                "-sps 0.1 "
              +
                # verbose logging
                "-v "
              +
                # log verbosity level
                "-lv 4 "
              +
                # colorize log output
                "--log-colors on "
              +
                # prefix each log line with its source
                "--log-prefix "
              +
                # include timestamps in logs
                "--log-timestamps "
              +
                # skip the warmup prefill
                "--no-warmup "
              +
                # max accepted length for speculative (dry) decoding
                "--dry-allowed-length 150 "
              +
                # speculative decoding multiplier
                "--dry-multiplier 0.4 "
              +
                # speculative decoding base
                "--dry-base 1.75 "
              +
                # speculative decoding last-n penalty
                "--dry-penalty-last-n 2000 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0";
            checkEndpoint = "/health";

            # Higher than the internal default of 10: llama-swap REJECTS (429)
            # past this instead of queueing, so it is the ceiling on how many
            # full-context chats can line up. They still generate one at a time
            # (-np 1); this just lets more wait.
            concurrencyLimit = 50;

            # What modalities this model exposes (used in /v1/models).
            # Fields left out are auto-filled from the upstream server.
            capabilities = {
              "in" = [
                "text"
                "image"
              ];
              out = [
                "text"
              ];
              tools = true;
              context = 262144;
            };

            # reasoning-effort variants behave exactly like the multi-slot model.
            aliases = [
              "\${MODEL_ID}#high"
              "\${MODEL_ID}#low"
              "\${MODEL_ID}#medium"
            ];

            # setParamsByID sets reasoning_effort per alias without reloading.
            filters = {
              setParamsByID = {
                "\${MODEL_ID}#medium" = {
                  chat_template_kwargs = {
                    reasoning_effort = "medium";
                  };
                };
                "\${MODEL_ID}#high" = {
                  chat_template_kwargs = {
                    reasoning_effort = "high";
                  };
                };
                "\${MODEL_ID}#low" = {
                  chat_template_kwargs = {
                    reasoning_effort = "low";
                  };
                };
              };
            };
          };

          # abltierated model
          "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = {
            name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
            cmd =
              "${llama-server} "
              +
                # llama-swap swaps the PORT macro for the model's runtime port
                "--port \${PORT} "
              +
                # remote HF GGUF model (APEX-I NanoPlus quant — SAME weights as above)
                "-hf IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF "
              +
                # image projection minimum tokens
                "--image-min-tokens 1024 "
              +
                # context size (tokens)
                "-c 262144 "
              +
                # batch size
                "-b 2048 "
              +
                # unified batch
                "-ub 512 "
              +
                # automatic load mode (GGUF load-alternative heuristics)
                "--load-mode auto "
              +
                # context memory (MiB)
                "-cram 16384 "
              +
                # context memory slots
                "-cms 2048 "
              +
                # health poll interval (ms)
                "--poll 50 "
              +
                # layers offloaded to GPU (auto = as many as fit)
                "-ngl auto "
              +
                # GPU index
                "-mg 0 "
              +
                # flash attention
                "-fa on "
              +
                # KV cache optimization
                "-kvo "
              +
                # repack weights for the target quant
                "--repack "
              +
                # offload image projectors
                "--op-offload "
              +
                # fan-in scale (mamba)
                "-fit on "
              +
                # fan-in iterations
                "-fitt 1024 "
              +
                # fan-in channels
                "-fitc 131072 "
              +
                # do NOT offload projectors to the iGPU (Tiel keeps mmproj on CUDA)
                "--no-mmproj-offload "
              +
                # sampling temperature
                "--temp 0.6 "
              +
                # top-k sampling
                "--top-k 20 "
              +
                # top-p (nucleus) sampling
                "--top-p 0.95 "
              +
                # min-p sampling
                "--min-p 0.0 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0 "
              +
                # reasoning effort on
                "-rea on "
              +
                # jinja chat template
                "--jinja "
              +
                # context key quantization
                "-ctk q8_0 "
              +
                # context value quantization
                "-ctv q8_0 "
              +
                # unified KV cache across modalities
                "--kv-unified "
              +
                # speculative decoding type (none = pure greedy)
                "--spec-type none "
              +
                # bind address
                "--host 0.0.0.0 "
              +
                # ONE parallel slot: the full 256k context belongs to the one
                # active sequence; other chats queue and are served one at a time.
                "-np 1 "
              +
                # continuous batching
                "-cb "
              +
                # cache prompt embeddings
                "--cache-prompt "
              +
                # cache idle model slots
                "--cache-idle-slots "
              +
                # number of model slots
                "--slots "
              +
                # idle unload timeout (ms)
                "-to 3600 "
              +
                # HTTP worker threads (-1 = auto)
                "--threads-http -1 "
              +
                # expose metrics endpoint
                "--metrics "
              +
                # enable the web UI
                "--webui "
              +
                # dense embedding model
                "--embedding "
              +
                # special-token penalty scale
                "-sps 0.1 "
              +
                # verbose logging
                "-v "
              +
                # log verbosity level
                "-lv 4 "
              +
                # colorize log output
                "--log-colors on "
              +
                # prefix each log line with its source
                "--log-prefix "
              +
                # include timestamps in logs
                "--log-timestamps "
              +
                # skip the warmup prefill
                "--no-warmup "
              +
                # max accepted length for speculative (dry) decoding
                "--dry-allowed-length 150 "
              +
                # speculative decoding multiplier
                "--dry-multiplier 0.4 "
              +
                # speculative decoding base
                "--dry-base 1.75 "
              +
                # speculative decoding last-n penalty
                "--dry-penalty-last-n 2000 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0";
            checkEndpoint = "/health";

            # Higher than the internal default of 10: llama-swap REJECTS (429)
            # past this instead of queueing, so it is the ceiling on how many
            # full-context chats can line up. They still generate one at a time
            # (-np 1); this just lets more wait.
            concurrencyLimit = 50;

            # What modalities this model exposes (used in /v1/models).
            # Fields left out are auto-filled from the upstream server.
            capabilities = {
              "in" = [
                "text"
                "image"
              ];
              out = [
                "text"
              ];
              tools = true;
              context = 262144;
            };

            # reasoning-effort variants behave exactly like the multi-slot model.
            aliases = [
              "\${MODEL_ID}#high"
              "\${MODEL_ID}#low"
              "\${MODEL_ID}#medium"
            ];

            # setParamsByID sets reasoning_effort per alias without reloading.
            filters = {
              setParamsByID = {
                "\${MODEL_ID}#medium" = {
                  chat_template_kwargs = {
                    reasoning_effort = "medium";
                  };
                };
                "\${MODEL_ID}#high" = {
                  chat_template_kwargs = {
                    reasoning_effort = "high";
                  };
                };
                "\${MODEL_ID}#low" = {
                  chat_template_kwargs = {
                    reasoning_effort = "low";
                  };
                };
              };
            };
          };

          # ---- MTP model (self-contained speculative decode) -------------------
          # IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF is a SELF-CONTAINED
          # MTP model: the MTP head is integrated into blk.40 inside the SAME 13 GB
          # file (no separate --model-draft needed). It is a DIFFERENT model from
          # Tiel (same 35B-A3B/qwen35moe family), so we run it as its own swappable
          # model with --spec-type draft-mtp. Single-GPU = no prefill penalty
          # (ggml #27428 only bites when the model is split across GPUs).
          #
          # Swap to it at runtime:
          #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"mtp"}'
          "Qwen3.6-35B-A3B-MTP" = {
            name = "Qwen3.6 35B A3B MTP (NanoPlus)";
            cmd =
              "${llama-server} "
              +
                # llama-swap swaps the PORT macro for the model's runtime port
                "--port \${PORT} "
              +
                # remote HF GGUF model (APEX-I NanoPlus quant)
                "-hf IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF "
              +
                # image projection minimum tokens
                "--image-min-tokens 1024 "
              +
                # context size (tokens)
                "-c 262144 "
              +
                # batch size
                "-b 2048 "
              +
                # unified batch
                "-ub 512 "
              +
                # automatic load mode (GGUF load-alternative heuristics)
                "--load-mode auto "
              +
                # context memory (MiB)
                "-cram 16384 "
              +
                # context memory slots
                "-cms 2048 "
              +
                # health poll interval (ms)
                "--poll 50 "
              +
                # layers offloaded to GPU (auto = as many as fit)
                "-ngl auto "
              +
                # GPU index
                "-mg 0 "
              +
                # flash attention
                "-fa on "
              +
                # KV cache optimization
                "-kvo "
              +
                # repack weights for the target quant
                "--repack "
              +
                # offload image projectors
                "--op-offload "
              +
                # fan-in scale (mamba)
                "-fit on "
              +
                # fan-in iterations
                "-fitt 512 "
              +
                # fan-in channels
                "-fitc 131072 "
              +
                # offload projectors to the iGPU (this MTP model needs it)
                "--mmproj-offload "
              +
                # iGPU device for the mmproj
                "--mmproj-device Vulkan0 "
              +
                # sampling temperature
                "--temp 0.6 "
              +
                # top-k sampling
                "--top-k 20 "
              +
                # top-p (nucleus) sampling
                "--top-p 0.95 "
              +
                # min-p sampling
                "--min-p 0.05 "
              +
                # repetition penalty — repeat last N prompts (0 = disabled)
                "--repeat-last-n 0 "
              +
                # jinja chat template
                "--jinja "
              +
                # context key quantization
                "-ctk q8_0 "
              +
                # context value quantization
                "-ctv q8_0 "
              +
                # unified KV cache across modalities
                "--kv-unified "
              +
                # speculative decoding type (self-contained MTP head)
                "--spec-type draft-mtp "
              +
                # max draft tokens for speculative decoding
                "--spec-draft-n-max 8 "
              +
                # minimum prob for a draft token to be accepted
                "--spec-draft-p-min 0.6 "
              +
                # bind address
                "--host 0.0.0.0 "
              +
                # max number of parallel requests
                "-np 3 "
              +
                # continuous batching
                "-cb "
              +
                # cache prompt embeddings
                "--cache-prompt "
              +
                # cache idle model slots
                "--cache-idle-slots "
              +
                # number of model slots
                "--slots "
              +
                # idle unload timeout (ms)
                "-to 3600 "
              +
                # HTTP worker threads (-1 = auto)
                "--threads-http -1 "
              +
                # expose metrics endpoint
                "--metrics "
              +
                # enable the web UI
                "--webui "
              +
                # dense embedding model
                "--embedding "
              +
                # special-token penalty scale
                "-sps 0.1 "
              +
                # verbose logging
                "-v "
              +
                # log verbosity level
                "-lv 4 "
              +
                # colorize log output
                "--log-colors on "
              +
                # prefix each log line with its source
                "--log-prefix "
              +
                # include timestamps in logs
                "--log-timestamps "
              +
                # skip the warmup prefill
                "--no-warmup";
            checkEndpoint = "/health";
            capabilities = {
              "in" = [
                "text"
                "image"
              ];
              out = [ "text" ];
              tools = true;
              context = 262144;
            };
          };

          "Qwen3.5-0.8B" = {
            name = "Qwen3.5-0.8B (titles)";
            cmd =
              "${llama-server} "
              +
                # llama-swap swaps the PORT macro for the model's runtime port
                "--port \${PORT} "
              +
                # remote HF GGUF model
                "-hf ggml-org/Qwen3.5-0.8B-GGUF "
              +
                # context size (tokens)
                "-c 8192 "
              +
                # batch size
                "-b 512 "
              +
                # sampling temperature (low for stable title generation)
                "--temp 0.3 "
              +
                # jinja chat template
                "--jinja "
              +
                # bind address
                "--host 0.0.0.0 "
              +
                # max number of parallel requests
                "-np 1 "
              +
                # HTTP read/write timeout (s) — NOT an unload timeout. A tiny
                # model finishing a short title in well under a second never
                # trips this; 120s is just a safe ceiling.
                "--timeout 120 "
              +
                # skip the warmup prefill
                "--no-warmup";
            checkEndpoint = "/health";

            # Unload after 120s idle so the model does NOT stay resident and
            # hog RAM. Next title reloads it (the load/unload cost we chose to
            # eat). ttl = 0 would mean "never unload" (the current global
            # default), which is exactly the RAM hog we want to avoid.
            ttl = 120;

            capabilities = {
              "in" = [ "text" ];
              out = [ "text" ];
              tools = false;
              context = 8192;
            };
          };
        };

        # ---- startup: preload the tiny title model, default profile = Tiel ----
        hooks = {
          on_startup = {
            # preload keeps the title model resident so titles are instant; it does
            # not make an incompatible model load. A ttl:0 model stays loaded.
            preload = [
              # "Qwen3-0.6B-Instruct"
            ];
            # start every session on the main coding model (not the MTP model)
            profile = "default";
          };
        };

        # ---- profiles (runtime-selectable model-ID rewrites) ----------------
        profiles = {
          "default" = {
            description = "Main coding model (Tiel-Coder 35B)";
            pins = {
              # "main" = the default/primary model
              "main" = "Tiel-Coder-35B-A3B";
            };
          };
          "mtp" = {
            description = "Speculative (MTP) decode — faster generation";
            pins = {
              "main" = "Qwen3.6-35B-A3B-MTP";
            };
          };
          # Single slot = the full 256k context belongs to whichever one chat
          # is generating; other chats queue and are served one at a time.
          # Great for long-context work where each turn needs the whole window.
          "full-context" = {
            description = "Single slot, full 256k context (requests queue, slower)";
            pins = {
              "main" = "Tiel-Coder-35B-A3B-HighContext";
            };
          };
        };

        # ---- profiles (runtime-selectable model-ID rewrites) ----------------
        # Only ONE profile may be active at a time; hooks.on_startup.profile
        # picks the startup one. With a single model this is a placeholder —
        # add more models under models: above, then pin them here, e.g.:
        #
        #   hooks.on_startup.profile = "deep";
        #   profiles = {
        #     "deep" = {
        #       description = "Maximum reasoning depth for hard tasks";
        #       pins = {
        #         "tiel" = "Tiel-Coder-35B-A3B:high";
        #       };
        #     };
        #     "fast" = {
        #       description = "Snappy replies, minimal thinking";
        #       pins = {
        #         "tiel" = "Tiel-Coder-35B-A3B:low";
        #       };
        #     };
        #   };
      };
    };

  # The Vulkan iGPU (Intel RPL-S) is reached by llama-server through the Vulkan
  # loader. The service runs as a DynamicUser with a restricted PATH, so the
  # loader can't find Intel's ICD via the default search path. Point
  # VK_ICD_FILENAMES directly at Intel's ICD JSON so the iGPU is enumerable.
  #
  # Only Intel is listed on purpose: the NVIDIA card is reached via CUDA, so
  # this makes the Vulkan device index == Intel RPL-S deterministically
  # (Vulkan0).
  #
  # CRITICAL: use the x86_64 ICD JSON, NOT the i686 one. The shipped
  # intel_icd.i686.json declares library_arch "32" but the loader is 64-bit, so
  # it silently rejects it and the iGPU never shows up. The x86_64 JSON pairs
  # with the 64-bit libvulkan_intel.so and is what actually enumerates.
  # (Set on the generated systemd service, not inside services.llama-swap.)
  systemd.services.llama-swap.environment.VK_ICD_FILENAMES =
    "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";

  # The module runs llama-swap as a DynamicUser (no group memberships), so it
  # can't open the NVIDIA device nodes (root:video, 660) for CUDA even though
  # it sets PrivateDevices = false. Uncomment to enable GPU:
  # systemd.services.llama-swap.supplementaryGroups = [ "video" ];

  /*
    services.ollama = {
      enable = true;
      package = pkgs-llama.ollama-cuda;
    };
  */
}
