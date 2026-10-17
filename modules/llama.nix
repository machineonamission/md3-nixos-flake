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
      llama-cpp = pkgs.llama-cpp-cuda;
      llama-server = lib.getExe' llama-cpp "llama-server";
    in
    {
      enable = true;
      port = 9930; # llama-swap front door
      # startPort = 5800; # default; ${PORT} starts here -> llama-server

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

            # --hf-token "REPLACE_WITH_YOUR_HF_TOKEN"
            cmd = "${llama-server} --port \${PORT} -hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF --image-min-tokens 1024 -c 262144 -b 2048 -ub 512 --load-mode auto -cram 16384 -cms 2048 --poll 50 -ngl auto -mg 0 -fa on -kvo --repack --op-offload -fit on -fitt 512 -fitc 131072 --no-mmproj-offload --temp 0.55 --top-k 20 --top-p 0.95 --min-p 0.05 --repeat-last-n 0 --dry-multiplier 0.1 --dry-allowed-length 4 -rea on --jinja -ctk q8_0 -ctv q8_0 --kv-unified --spec-type none --host 0.0.0.0 -np 3 -cb --cache-prompt --cache-idle-slots --slots -to 3600 --threads-http -1 --metrics --webui --embedding -sps 0.1 -v -lv 4 --log-colors on --log-prefix --log-timestamps --no-warmup";

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
            # key, so `Tiel-Coder-35B-A3B:high` selects reasoning_effort: high
            # without reloading. Protected params like "model" can't be changed.
            setParamsByID = {
              "\${MODEL_ID}#:medium" = {
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

            # concurrencyLimit = 0; # 0 = internal default of 10
            # ttl = 0; # 0 = never auto-unload; -1 = use global globalTTL
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
