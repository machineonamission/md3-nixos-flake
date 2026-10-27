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
  # HOW THE MODULE WORKS:
  #   `services.llama-swap.settings` is a FREEFORM YAML value. The module
  #   serialises it to config.yaml and runs `llama-swap -validate` at build
  #   time (options.services.llama-swap.validateConfigFile, default true).
  #   That validator checks it against config-schema.json automatically.
  #
  #   So you do NOT hand-translate the whole JSON schema into Nix. You just
  #   add the fields you care about and let the validator catch typos / wrong
  #   types at `nix build` time.
  #
  # REASONING-VARIANT WARNINGS (this answers "am I doing it wrong"):
  #   * OpenCode's model selector generates its OWN low/medium/high variants
  #     automatically for any llama-swap model (via the openai-compatible
  #     protocol). You do NOT need `aliases` / `setParamsByID` for that.
  #   * `setParamsByID` is only useful for non-OpenCode API clients that
  #     request `ModelID#high` directly. When used, reasoning_effort MUST be
  #     top-level — llama.cpp reads it at the top of the request body
  #     (server-common.cpp: `if (body.contains("reasoning_effort"))`). The
  #     nested `chat_template_kwargs` form is silently ignored, which was the
  #     "No reasoning" bug.
  #
  # "PROFILES" (runtime model-ID rewrites, switched via the UI/API) are a
  #   SEPARATE feature from the reasoning-effort variants above. They only
  #   make sense once you have more than one model.
  #
  # MODEL-DATA PASSING TO OpenCode (opencode-models-discovery plugin):
  #   The plugin reads meta.llamaswap.max_input_tokens / max_output_tokens
  #   from /v1/models to set the Input / Output limits. llama-swap does NOT
  #   emit these by default, so the plugin fell back to a bogus Output=32000
  #   and Input=unknown. Putting them in each model's `metadata` map surfaces
  #   them verbatim in meta.llamaswap (llama-swap only caps the keys
  #   architecture/capabilities/supported_parameters/context_length/
  #   context_window — max_input_tokens/max_output_tokens are NOT capped).
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

      # Shared llama-server command line for the 35B-A3B family. ~40 flags are
      # identical across all three big models; only four things differ, so they
      # become arguments instead of being copied three times:
      #   hf              — remote HF GGUF repo (the weights)
      #   np              — parallel slots (3 = pipelined, 1 = full 256k context)
      #   fitt            — fan-in iterations (MTP model uses 512)
      #   offloadMMProj   — true = offload mmproj to the Intel iGPU (Vulkan0)
      modelCmd =
        {
          hf,
          np ? 3,
          fitt ? 1024,
          offloadMMProj ? false,
        }:
        let
          mmproj =
            if offloadMMProj then
              [
                "--mmproj-offload"
                "--mmproj-device"
                "Vulkan0"
              ]
            else
              [ "--no-mmproj-offload" ];
        in
        lib.concatStringsSep " " (
          [
            "${llama-server}"
            "--port \${PORT}"
            "-hf ${hf}"
            "--image-min-tokens 1024"
            "-c 262144"
            "-b 2048"
            "-ub 512"
            "--load-mode auto"
            "-cram 16384"
            "-cms 2048"
            "--poll 50"
            "-ngl auto"
            "-mg 0"
            "-fa on"
            "-kvo"
            "--repack"
            "--op-offload"
            "-fit on"
            "-fitt ${toString fitt}"
          ]
          ++ mmproj
          ++ [
            "--temp 0.6"
            "--top-k 20"
            "--top-p 0.95"
            "--min-p 0.0"
            "--repeat-last-n 0"
            "-rea on"
            "--jinja"
            "-ctk q8_0"
            "-ctv q8_0"
            "--kv-unified"
            "--spec-type none"
            "--host 0.0.0.0"
            "-np ${toString np}"
            "-cb"
            "--cache-prompt"
            "--cache-idle-slots"
            "--slots"
            "-to 3600"
            "--threads-http -1"
            "--metrics"
            "--webui"
            "--embedding"
            "-sps 0.1"
            "-v"
            "-lv 4"
            "--log-colors on"
            "--log-prefix"
            "--log-timestamps"
            "--no-warmup"
            "--dry-allowed-length 150"
            "--dry-multiplier 0.6"
            "--dry-base 1.75"
            "--dry-penalty-last-n 2000"
            "--repeat-last-n 0"
          ]
        );

      # Builds a full llama-swap model for the 35B-A3B family. The three big
      # models share the command line above PLUS identical reasoning-effort
      # variants, so only the display name, parallel slots (-np), and the
      # concurrency ceiling differ — those are the only arguments.
      model35B =
        {
          name, # human-readable name shown in /v1/models
          hf, # remote HF GGUF repo (the weights)
          np ? 3, # parallel slots: 3 = pipelined, 1 = full 256k
          concurrencyLimit ? 0, # 0 = llama-swap default (10)
          fitt ? 1024, # fan-in iterations
          offloadMMProj ? false, # true = offload mmproj to the Intel iGPU
        }:
        {
          inherit name;
          cmd = modelCmd {
            inherit
              hf
              np
              fitt
              offloadMMProj
              ;
          };
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

          # Arbitrary selector metadata, passed through verbatim into /v1/models.
          # Idiomatic llama-swap way to expose model identity that
          # autodiscovery can't infer from the weights alone.
          #
          # max_input_tokens / max_output_tokens drive OpenCode's Input/Output
          # limits (see top-of-file note). 262144 == the 256k context window;
          # 32768 is a sane generation ceiling for this model class.
          metadata = {
            hf_repo = hf;
            quant = "APEX-I-NanoPlus";
            max_input_tokens = 262144;
            max_output_tokens = 32768;
          };
          includeAliasesInList = true;

          # reasoning-effort variants (no reload). OpenCode already generates its
          # own low/medium/high variants for this model, so these aliases are
          # ONLY for API clients that request `ModelID#high` directly.
          #
          # CRITICAL: reasoning_effort MUST be top-level. llama.cpp reads it at
          # the top of the request body, so the nested `chat_template_kwargs`
          # form is silently ignored — that was the "No reasoning" bug.
          aliases = [
            "\${MODEL_ID}:high"
            "\${MODEL_ID}:low"
            "\${MODEL_ID}:medium"
          ];
          filters = {
            setParamsByID = {
              "\${MODEL_ID}:high" = {
                reasoning_effort = "high";
              };
              "\${MODEL_ID}:medium" = {
                reasoning_effort = "medium";
              };
              "\${MODEL_ID}" = {
                reasoning_effort = "medium";
              };
              "\${MODEL_ID}:low" = {
                reasoning_effort = "low";
              };
            };
          };
        };
    in
    {
      enable = true;
      port = 9930; # llama-swap front door
      listenAddress = "0.0.0.0"; # allow other devices to access webui lol

      settings = {
        # ---- global settings ------------------------------------------------
        # healthCheckTimeout is in SECONDS (schema min 15, default 120).
        # 500 is fine for a big model that takes a while to load.
        healthCheckTimeout = 500;
        sendLoadingState = true; # inject loading updates into the reasoning field

        # ---- models ---------------------------------------------------------
        models = {
          "Tiel-Coder-35B-A3B" = model35B {
            name = "Tiel Coder 35B A3B (NanoPlus)";
            hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
            # np defaults to 3 (pipelined), concurrencyLimit to 0 (llama-swap default)
          };

          # Single slot → the ENTIRE 256k KV pool belongs to whichever one
          # sequence is generating; other chats queue and are served one at a
          # time (continuous batching still speeds up prompt prefill).
          "Tiel-Coder-35B-A3B-HighContext" = model35B {
            name = "Tiel Coder 35B A3B (Single Slot — Full Context)";
            hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
            np = 1; # one slot → full 256k context for the one sequence
            concurrencyLimit = 50; # more full-context chats can queue (still 1-at-a-time)
          };

          "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = model35B {
            name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
            hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
            np = 1;
            concurrencyLimit = 50;
          };

          # ---- MTP model (self-contained speculative decode) ----------------
          # IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF is a SELF-CONTAINED
          # MTP model: the MTP head is integrated into blk.40 inside the SAME file
          # (no separate --model-draft needed). It is a DIFFERENT model from Tiel
          # (same 35B-A3B/qwen35moe family), so it has its own command line: no
          # reasoning_effort, MTP spec instead of `none`, and it offloads the
          # mmproj to the iGPU. Swap to it at runtime:
          #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"mtp"}'
          "Qwen3.6-35B-A3B-MTP" = {
            name = "Qwen3.6 35B A3B MTP (NanoPlus)";
            cmd = lib.concatStringsSep " " ([
              "${llama-server}"
              "--port \${PORT}"
              "-hf IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF"
              "--image-min-tokens 1024"
              "-c 262144"
              "-b 2048"
              "-ub 512"
              "--load-mode auto"
              "-cram 16384"
              "-cms 2048"
              "--poll 50"
              "-ngl auto"
              "-mg 0"
              "-fa on"
              "-kvo"
              "--repack"
              "--op-offload"
              "-fit on"
              "-fitt 512"
              "--mmproj-offload"
              "--mmproj-device Vulkan0"
              "--temp 0.6"
              "--top-k 20"
              "--top-p 0.95"
              "--min-p 0.05"
              "--repeat-last-n 0"
              "--jinja"
              "-ctk q8_0"
              "-ctv q8_0"
              "--kv-unified"
              "--spec-type draft-mtp"
              "--spec-draft-n-max 8"
              "--spec-draft-p-min 0.6"
              "--host 0.0.0.0"
              "-np 3"
              "-cb"
              "--cache-prompt"
              "--cache-idle-slots"
              "--slots"
              "-to 3600"
              "--threads-http -1"
              "--metrics"
              "--webui"
              "--embedding"
              "-sps 0.1"
              "-v"
              "-lv 4"
              "--log-colors on"
              "--log-prefix"
              "--log-timestamps"
              "--no-warmup"
            ]);
            checkEndpoint = "/health";
            metadata = {
              hf_repo = "IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF";
              quant = "APEX-I-NanoPlus";
              spec_type = "draft-mtp";
              max_input_tokens = 262144;
              max_output_tokens = 32768;
            };
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

          # Tiny model for title generation. Unloaded after 120s idle so it
          # doesn't stay resident and hog RAM; the next title reloads it (the
          # load/unload cost we chose to eat). ttl = 0 would be "never unload".
          "Qwen3.5-0.8B" = {
            name = "Qwen3.5-0.8B (titles)";
            cmd = lib.concatStringsSep " " ([
              "${llama-server}"
              "--port \${PORT}"
              "-hf ggml-org/Qwen3.5-0.8B-GGUF"
              "-c 8192"
              "-b 512"
              "--temp 0.3" # low for stable title generation
              "--jinja"
              "--host 0.0.0.0"
              "-np 1"
              # HTTP read/write timeout (s) — NOT an unload timeout. A tiny
              # model finishing a short title in well under a second never
              # trips this; 120s is just a safe ceiling.
              "--timeout 120"
              "--no-warmup"
            ]);
            checkEndpoint = "/health";
            ttl = 120;
            metadata = {
              max_input_tokens = 8192;
              max_output_tokens = 2048;
            };
            capabilities = {
              "in" = [ "text" ];
              out = [ "text" ];
              tools = false;
              context = 8192;
            };
          };
        };

        # ---- startup: default profile = main coding model ----
        hooks = {
          on_startup = {
            # preload keeps a model resident so it's instant; it does NOT make an
            # incompatible model load. A ttl:0 model stays loaded.
            preload = [
              # "Qwen3-0.6B-Instruct"
            ];
            # start every session on the main coding model (not the MTP model)
            profile = "default";
          };
        };

        # ---- profiles (runtime-selectable model-ID rewrites) ----------------
        # Only ONE profile may be active at a time; hooks.on_startup.profile
        # picks the startup one.
        profiles = {
          "default" = {
            description = "Main coding model (Tiel-Coder 35B)";
            pins = {
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
          "full-context" = {
            description = "Single slot, full 256k context (requests queue, slower)";
            pins = {
              "main" = "Tiel-Coder-35B-A3B-HighContext";
            };
          };
        };
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
