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
  #   * OpenCode only auto-generates low/medium/high variants when the
  #     discovery format advertises `reasoning_options`. The llama-swap format
  #     does NOT populate that, so we do NOT rely on auto-generation.
  #   * Do NOT use `aliases` / `setParamsByID` here: includeAliasesInList would
  #     emit aliased ids as SEPARATE /v1/models rows, splitting the model into
  #     several top-level entries in OpenCode. Variants are declared explicitly
  #     in opencode.jsonc (providers.llama-swap.models.<id>.variants).
  #   * The request-body reasoning_effort that OpenCode's variant overlay sends
  #     is read at the top of the body by llama.cpp
  #     (server-common.cpp: `if (body.contains("reasoning_effort"))`); the
  #     nested `chat_template_kwargs` form is silently ignored ("No reasoning" bug).
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
      #   * Vulkan-> Intel Graphics RPL-S (iGPU (mmproj is forced to CPU; Vulkan loader stays built but unused))
      # We keep the heavy model on CUDA and keep mmproj on the CPU
      # (the iGPU is slow integrated graphics — putting model layers there would
      # tank generation speed).
      llama-cpp = pkgs-llama.llama-cpp.override {
        cudaSupport = true;
        vulkanSupport = true;
      };
      llama-server = lib.getExe' llama-cpp "llama-server";

      # baseCmd — the shared command line for the APEX-I-NanoPlus family,
      # written ONCE. ~40 flags are identical across every model; only four
      # knobs differ, so they become arguments instead of being copied per
      # model:
      #   hf              — remote HF GGUF repo (the weights)
      #   ctx             — context window in tokens (262144 default; LFM2.5
      #                     uses 131072)
      #   np              — parallel slots (3 = pipelined, 1 = full context)
      #   fitt            — fan-in iterations (MTP model uses 512)
      #   offloadMMProj   — true = force mmproj to the CPU (iGPU/Vulkan0 garbles every image model)
      #   extra           — raw flag list, appended LAST so per-model flags
      #                     live next to the model that needs them
      #
      # Returns a LIST of flags so callers can concatenate before joining.
      baseCmd =
        {
          hf,
          ctx ? 262144,
          np ? 1,
          fitt ? 1024,
          offloadMMProj ? false,
          extra ? [ ],
        }:
        let
          # Image models load the small mmproj ON THE CPU (forced). The Intel
          # iGPU / Vulkan0 path garbles every image model, every single time, so
          # we never offload it — --mmproj-device CPU pins it to the CPU. Text
          # models get --no-mmproj-offload.
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
        [
          "${llama-server}"
          "--port \${PORT}"
          "-hf ${hf}"
          "--image-min-tokens 1024"
          "-c ${toString ctx}"
          "-b 2048"
          "-ub 512"
          "--load-mode auto"
          "--kv-unified"
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
          "--min-p 0.05"
          "--repeat-last-n 0"
          "-rea on"
          "--jinja"
          "-ctk q8_0"
          "-ctv q8_0"
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
          # if i need dry again it fucks with like, oh i want to type a path 5 times and dry is like nuh uh
          # "--dry-allowed-length 30"
          # "--dry-multiplier 0.4"
          # "--dry-base 1.75"
          # "--dry-penalty-last-n 2000"
          # ---- OUTPUT + REASONING CAPS ------------------------------------
          # --n-predict hard-caps tokens per response. -1 (llama.cpp default)
          # would let the model generate until the context window; 32768 matches
          # metadata.max_output_tokens so both layers agree on the ceiling.
          "--n-predict"
          "32768"
          # --reasoning-budget is the circuit breaker for the thinking-loop
          # doomloop: a hard token cap on the internal-thinking phase so it can
          # never eat the whole context window. --reasoning-effort medium is the
          # vendor's default depth; this is the hard ceiling on top of it.
          "--reasoning-budget"
          "16384"
          # injected before the end-of-thinking tag when the budget runs out, so
          # the model stops looping and emits a real answer instead of cutting off.
          #"--reasoning-budget-message"
          #"Reasoning budget reached: stop thinking and give your final answer now."
          #"--reasoning-effort"
          #"medium"
          # ---- SAMPLING (vendor APEX-I-NanoPlus defaults) ----------------
          # Repeat/freq/presence penalties DISABLED — vendor requirement for
          # code: repeat_penalty must be 1.0 and presence/frequency 0.0, else
          # `{` / `=` / indentation tokens get penalized and the model swaps chars.
          "--repeat-penalty"
          "1.0"
          "--presence-penalty"
          "0.0"
          "--frequency-penalty"
          "0.0"
        ]
        ++ extra;

      # mtpExtra — speculative decode (MTP) with a SEPARATE draft head:
      # Occamy-1.0 and KAT-Coder-V2.5-Dev ship a standalone mtp-*.gguf in the
      # SAME repo, so --draft-model targets it with `repo:file` — llama.cpp's
      # HF file targeting, the same syntax `--hf` uses. Returns the flag list
      # for `model` to append.
      #   repo            — the model's HF repo (holds the draft head too)
      #   file            — the standalone draft .gguf filename
      #   specDraftNMax   — Occamy's documented knob (max draft tokens)
      #   draftMax        — KAT's documented alias for the same knob
      mtpExtra =
        {
          repo,
          file,
          specDraftNMax ? 2,
          draftMax ? null,
        }:
        [
          "--spec-type"
          "draft-mtp"
          "--draft-model"
          "${repo}:${file}"
        ]
        ++ (
          if draftMax != null then
            [
              "--draft-max"
              (toString draftMax)
            ]
          else
            [ ]
        )
        ++ (
          if specDraftNMax != null then
            [
              "--spec-draft-n-max"
              (toString specDraftNMax)
            ]
          else
            [ ]
        );

      # model — builds a full llama-swap model entry. Wraps baseCmd (the shared
      # command) with the per-model capabilities + metadata. Every field that
      # varies across the collection is an argument, so adding a model is just a
      # literal with the knobs it needs — no flag copying.
      #   name              — human-readable name shown in /v1/models
      #   hf                — remote HF GGUF repo (the weights)
      #   image             — true = multimodal (has an mmproj); sets capabilities.in
      #   ctx               — context window in tokens (262144 default)
      #   quant             — quant label surfaced in metadata (NanoPlus / -V2.1)
      #   offloadMMProj     — true = force mmproj to the CPU (iGPU/Vulkan0 garbles every image model)
      #   np                — parallel slots (3 = pipelined, 1 = full context)
      #   concurrencyLimit  — 0 = llama-swap default (10)
      #   fitt              — fan-in iterations (MTP model uses 512)
      #   extra             — raw flag list appended to the base command
      #   mtp               — optional fn repo -> flags for a SEPARATE MTP draft head
      model =
        {
          name,
          hf,
          image ? false,
          ctx ? 262144,
          quant ? "APEX-I-NanoPlus",
          offloadMMProj ? false,
          np ? 1,
          concurrencyLimit ? 0,
          fitt ? 1024,
          extra ? [ ],
          mtp ? null,
        }:
        {
          inherit name;
          # base command ++ separate-draft MTP flags (if any) ++ extra overrides
          cmd = lib.concatStringsSep " " (
            (baseCmd {
              inherit
                hf
                ctx
                np
                fitt
                offloadMMProj
                extra
                ;
            })
            ++ (if mtp != null then mtp hf else [ ])
          );
          checkEndpoint = "/health";

          capabilities = {
            "in" =
              if image then
                [
                  "text"
                  "image"
                ]
              else
                [ "text" ];
            out = [ "text" ];
            tools = true;
            context = ctx;
          };

          # Arbitrary selector metadata, passed through verbatim into /v1/models.
          # Idiomatic llama-swap way to expose model identity that
          # autodiscovery can't infer from the weights alone.
          #
          # max_input_tokens == the context window; max_output_tokens drives
          # OpenCode's Output limit (32768 here).
          metadata = {
            hf_repo = hf;
            inherit quant;
            max_input_tokens = ctx;
            max_output_tokens = 32768;
          }
          // lib.optionalAttrs (concurrencyLimit != 0) { inherit concurrencyLimit; };

          # VARIANTS (low/medium/high/noreasoning) are declared in
          # opencode.jsonc (providers.llama-swap.models.<id>.variants).
          # We do NOT set aliases or setParamsByID here: includeAliasesInList
          # would emit aliased ids as SEPARATE /v1/models rows (splitting
          # the model in OpenCode), and setParamsByID's base rule would
          # override the request-body reasoning_effort that OpenCode's own
          # variant overlay sends. The llama-swap discovery format does not
          # populate `reasoning_options`, so OpenCode does not auto-generate.
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
        includeAliasesInList = false; # aliased ids are variants in opencode.jsonc, not separate /v1/models rows

        # ---- models ---------------------------------------------------------
        models = {
          # ---- main coding family (35B-A3B, image) --------------------------
          "Tiel-Coder-35B-A3B" = model {
            name = "Tiel Coder 35B A3B (NanoPlus)";
            hf = "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
            image = true;
            # np defaults to 1 (full context slot); concurrencyLimit to 0 (llama-swap default)
          };

          "Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" = model {
            name = "CYBER (ABLITERATED) Tiel Coder 35B A3B";
            hf = "IsValorum/Cyber-Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF";
            image = true;
            # np defaults to 1 (full context slot); concurrencyLimit to 0 (llama-swap default)
            concurrencyLimit = 50;
          };

          # ---- VAL-APEX-I NanoPlus V3 — Qwen3.8 27B dense hybrid ------------
          # The 27B dense-hybrid family (Gated DeltaNet + full-attention, 64
          # layers, native 256K). Both ship a Q8_0 mmproj, so offload it to the
          # Intel iGPU like the other image models. Safe (standard) vs
          # abiterated (directional refusal-vector removal over Qwen3.8-27B).
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

          # ---- APEX-I-NanoPlus collection: text models ----------------------
          "LFM2.5-24B-A2B" = model {
            name = "LFM2.5 24B A2B (NanoPlus)";
            hf = "IsValorum/LFM2.5-24B-A2B-APEX-I-NanoPlus-GGUF";
            # text-only (no mmproj); smaller 128k context window
            ctx = 131072;
          };

          "Qwen3.8-Flash-Coder" = model {
            name = "Qwen3.8 Flash Coder (NanoPlus)";
            hf = "IsValorum/Qwen3.8-Flash-Coder-APEX-I-NanoPlus-GGUF";
            # text-only, qwen4exp architecture
          };

          # ---- Flash Next — 16 GB VRAM quant (no IsValorum APEX quant) -------
          # IsValorum only ships "Flash Coder", NOT "Flash Next", so there is no
          # APEX-I-NanoPlus quant for it. The base Qwen3.8-Flash-Next is a huge
          # ~167 GB BF16 qwen4_exp MoE, so I picked the best low-VRAM fit instead:
          #   * zephel01's L448 quant is a SINGLE quant (3 shards) — clean for
          #     `-hf <repo>`. The popular repos (bartowski/unsloth/ISTA) ship
          #     dozens of quants and break bare `-hf`, so they're out.
          #   * built for a 12 GB VRAM / 32 GB RAM machine → ideal for the 16 GB
          #     dGPU with heavy CPU offload.
          #   * repo ships NO mmproj, so this is text-only here.
          "Qwen3.8-Flash-Next" = model {
            name = "Qwen3.8 Flash Next (L448, 16GB)";
            hf = "zephel01/Qwen3.8-Flash-Next-12G32G-GGUF";
            quant = "L448 (zephel01, 16GB)";
            # text-only (no mmproj in this repo); qwen4_exp, 262k context
          };

          "Thomson-1.0-Small" = model {
            name = "Thomson 1.0 Small (NanoPlus)";
            hf = "IsValorum/Thomson-1.0-Small-APEX-I-NanoPlus-GGUF";
            # text-only
          };

          # ---- APEX-I-NanoPlus collection: image models ---------------------
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

          # ---- APEX-I-NanoPlus-V2.1 collection ------------------------------
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

          # ---- APEX-I-NanoPlus-V2.1: MTP with a SEPARATE draft head ---------
          "KAT-Coder-V2.5-Dev" = model {
            name = "KAT-Coder V2.5 Dev (V2.1)";
            hf = "IsValorum/KAT-Coder-V2.5-Dev-APEX-I-NanoPlus-V2.1-GGUF";
            quant = "APEX-I-NanoPlus-V2.1";
            # text-only; MTP uses a SEPARATE standalone draft head in the same
            # repo, targeted with `repo:file` (llama.cpp HF file targeting).
            # KAT documents the knob as --draft-max (vs Occamy's --spec-draft-n-max).
            mtp =
              hf:
              mtpExtra {
                repo = hf;
                file = "mtp-KAT-Coder-V2.5-Dev-Q4_0.gguf";
                draftMax = 2;
              };
          };

          # ---- APEX-I-NanoPlus: MTP with a SEPARATE draft head --------------
          "Occamy-1.0" = model {
            name = "Occamy 1.0 (NanoPlus)";
            hf = "IsValorum/Occamy-1.0-APEX-I-NanoPlus-GGUF";
            image = true;
            # MTP uses a SEPARATE standalone draft head in the same repo,
            # targeted with `repo:file`. Occamy documents the knob as
            # --spec-draft-n-max (vs KAT's --draft-max alias).
            mtp =
              hf:
              mtpExtra {
                repo = hf;
                file = "occamy-1.0-mtp-Q4_K_M.gguf";
              };
          };

          # ---- MTP model (self-contained speculative decode) ----------------
          # IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF is a SELF-CONTAINED
          # MTP model: the MTP head is integrated into blk.40 inside the SAME file
          # (no separate --model-draft needed). It is a DIFFERENT model from Tiel
          # (same 35B-A3B/qwen35moe family), so it has its own command line: no
          # reasoning_effort, MTP spec instead of `none`, and it offloads the
          # mmproj to the iGPU. Swap to it at runtime:
          #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"mtp"}'
          "Qwen3.6-35B-A3B-MTP" = model {
            name = "Qwen3.6 35B A3B MTP (NanoPlus)";
            hf = "IsValorum/Qwen3.6-35B-A3B-MTP-APEX-I-NanoPlus-GGUF";
            image = true;
            fitt = 512; # higher fan-in for the self-contained MTP head
            # SELF-CONTAINED MTP: the MTP head lives inside blk.40 of the SAME
            # file (no --draft-model). Same 35B-A3B/qwen35moe family as Tiel, so
            # it reuses baseCmd; only the spec flags differ from `--spec-type none`.
            # Swap to it at runtime:
            #   curl -X PUT localhost:9930/api/profiles/active -d '{"name":"mtp"}'
            extra = [
              "--spec-type"
              "draft-mtp"
              "--spec-draft-n-max"
              "2"
              "--spec-draft-p-min"
              "0.6"
            ];
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
