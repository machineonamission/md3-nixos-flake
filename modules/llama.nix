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
      listenAddress = "0.0.0.0";  # allow other devices to access webui lol
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

            # model reported output was garbled, disabling  for now
            # --mmproj-device Vulkan0
            #
            cmd = "${llama-server} --port \${PORT} -hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF --image-min-tokens 1024 -c 262144 -b 2048 -ub 512 --load-mode auto -cram 16384 -cms 2048 --poll 50 -ngl auto -mg 0 -fa on -kvo --repack --op-offload -fit on -fitt 512 -fitc 131072 --no-mmproj-offload  --temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.05 --repeat-last-n 0 --dry-multiplier 0 -rea on --jinja -ctk q8_0 -ctv q8_0 --kv-unified --spec-type none --host 0.0.0.0 -np 2 -cb --cache-prompt --cache-idle-slots --slots -to 3600 --threads-http -1 --metrics --webui --embedding -sps 0.1 -v -lv 4 --log-colors on --log-prefix --log-timestamps --no-warmup";

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
            cmd = "${llama-server} --port \${PORT} -hf IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF --image-min-tokens 1024 -c 262144 -b 2048 -ub 512 --load-mode auto -cram 16384 -cms 2048 --poll 50 -ngl auto -mg 0 -fa on -kvo --repack --op-offload -fit on -fitt 512 -fitc 131072 --mmproj-offload --mmproj-device Vulkan0 --temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.05 --repeat-last-n 0 --jinja -ctk q8_0 -ctv q8_0 --kv-unified --spec-type draft-mtp --spec-draft-n-max 8 --spec-draft-p-min 0.6 --host 0.0.0.0 -np 2 -cb --cache-prompt --cache-idle-slots --slots -to 3600 --threads-http -1 --metrics --webui --embedding -sps 0.1 -v -lv 4 --log-colors on --log-prefix --log-timestamps --no-warmup";
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

          # ---- tiny title model (fast session titles) --------------------------
          # Qwen3-0.6B-Instruct (Q8_0 ~700MB). Runs on CPU — no iGPU/CUDA needed.
          # Preloaded on startup so session titles are instant instead of loading
          # the 13 GB main model every time.
          "Qwen3-0.6B-Instruct" = {
            name = "Qwen3 0.6B (titles)";
            cmd = "${llama-server} --port \${PORT} -hf Qwen/Qwen3-0.6B-GGUF -c 8192 -b 512 --temp 0.3 --jinja --host 0.0.0.0 -np 1 -to 120 --no-warmup";
            checkEndpoint = "/health";
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
              "Qwen3-0.6B-Instruct"
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
