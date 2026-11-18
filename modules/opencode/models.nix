# modules/opencode/models.nix
#
# Provider + model generation for the generated opencode.jsonc.
#
# The old hand-written config pasted 7 near-identical llama-swap model blobs
# (coder / coder-unsafe / coder-mtp / moe / mixed / swap-back / title). Every
# one of them shared the same reasoning capabilities, token limits and
# low/medium/high/noreasoning variants — only the display name, the default
# reasoning_effort and a couple of knobs on `title` differed. This file turns
# that duplication into a small declarative list.
{
  lib,
  ...
}:
let
  # -------------------------------------------------------------------------
  # JSON serialization
  # -------------------------------------------------------------------------
  # We build opencode.jsonc as a Nix value and pretty-print it so the generated
  # file stays human / LLM readable. Attrset keys are sorted for a reproducible
  # store path across rebuilds.

  isScalar =
    v: builtins.isString v || builtins.isBool v || builtins.isInt v || builtins.isFloat v || v == null;

  toJson =
    indent: value:
    if isScalar value then
      if builtins.isString value then
        "\"${escapeJSON value}\""
      else if value == null then
        "null"
      else if builtins.isBool value then
        (if value then "true" else "false")
      else
        toString value
    else if builtins.isList value then
      if value == [ ] then
        "[]"
      else
        "[\n"
        + lib.concatStringsSep ",\n" (
          builtins.map (item: indent + "  " + toJson (indent + "  ") item) value
        )
        + "\n"
        + indent
        + "]"
    else
      # attrset
      let
        keys = builtins.sort (a: b: a < b) (builtins.attrNames value);
      in
      if keys == [ ] then
        "{}"
      else
        "{\n"
        + lib.concatStringsSep ",\n" (
          builtins.map (
            k: indent + "  " + "\"${escapeJSON k}\"" + ": " + toJson (indent + "  ") value.${k}
          ) keys
        )
        + "\n"
        + indent
        + "}";

  # Minimal JSON string escaper (this nixpkgs lacks escapeJSON).
  # Escapes backslash and double-quote first; \n/\r/\t for readability.
  # Raw unicode (emoji, accents) is valid in JSON strings, so left as-is.
  escapeJSON =
    s: builtins.replaceStrings [ "\\" "\"" "\n" "\r" "\t" ] [ "\\\\" "\\\"" "\\\\n" "\\\\r" "\\\\t" ] s;

  # Pretty-print a Nix value as indented JSON.
  prettyJson = value: toJson "" value;

  # -------------------------------------------------------------------------
  # llama-swap models
  # -------------------------------------------------------------------------
  # Shared reasoning capabilities for every llama-swap coder model.
  baseCapabilities = {
    input = [
      "text"
      "image"
    ];
    output = [ "text" ];
    reasoning = {
      toggle = true;
      budget = {
        max = 16384;
      };
      supported = true;
      effort = [
        "none"
        "low"
        "medium"
        "high"
      ];
    };
    temperature = true;
    tools = true;
  };

  # The 4 variants every coder model exposes. The `noreasoning` variant does not
  # just set reasoning_effort=none — it also flips the thinking template OFF via
  # the request body (llama.cpp 0.8.0 rejects a quoted string there, so this is a
  # JSON boolean). See the big comment in the original opencode.jsonc.
  reasoningVariants = effort: [
    {
      id = "low";
      settings = {
        reasoningEffort = "low";
      };
    }
    {
      id = "medium";
      settings = {
        reasoningEffort = "medium";
      };
    }
    {
      id = "high";
      settings = {
        reasoningEffort = "high";
      };
    }
    {
      id = "noreasoning";
      settings = {
        reasoningEffort = "none";
      };
      body = {
        chat_template_kwargs = {
          enable_thinking = false;
        };
      };
    }
  ];

  # A llama-swap coder model. The base fields (capabilities, limits, variants)
  # come from discovery + this helper; the explicit declaration is required
  # because the llama-swap discovery format does not populate `reasoning_options`,
  # so OpenCode would not auto-generate the low/medium/high selector otherwise.
  coderModel =
    {
      name,
      effort, # default reasoning_effort for a bare selection
      capabilities ? baseCapabilities,
      limit ? {
        context = 262144;
        input = 262144;
        output = 32768;
      },
      body ? { },
    }:
    {
      inherit name;
      type = "chat";
      inherit capabilities;
      inherit limit;
      settings = {
        reasoningEffort = effort;
      };
      variants = reasoningVariants effort;
    }
    // lib.optionalAttrs (body != { }) {
      inherit body;
    };

  # The coders Melody actually swaps between. The model key (e.g. `coder`) is the
  # OpenCode model-ID — it is NOT emitted as a redundant `id` field, which the
  # config schema does not recognize. `name` is what shows in the picker;
  # `effort` is the default reasoning level for a bare selection.
  llamaSwapCoders = {
    # full 35B-A3B coders — swap-back reverts to the default full coder
    "coder" = coderModel {
      name = "Coder Safe (GPU)";
      effort = "medium";
    };
    "swap-back" = coderModel {
      name = "Coder (Swap Back)";
      effort = "medium";
    };
    # abliterated variant (the "unsafe" coder)
    "coder-unsafe" = coderModel {
      name = "Abliterated Coder (GPU)";
      effort = "high";
    };
    # speculative-decoding (MTP) variant of the full coder
    "coder-mtp" = coderModel {
      name = "Coder (MTP) (GPU)";
      effort = "high";
    };
    # pure MoE coder (Ornith) — A/B against the default full coder (Tiel)
    "moe" = coderModel {
      name = "MoE Coder (GPU)";
      effort = "medium";
    };
    # dense / hybrid Qwen3.8-27B family
    "mixed" = coderModel {
      name = "Hybrid Coder (GPU)";
      effort = "high";
    };
  }
  // {
    # tiny iGPU title model: text-only, no tools, tiny context, thinking OFF.
    # Its reasoning budget is tiny (2048) — the general 16384 budget only applies
    # to the big coders, so override it here (shallow `//` replaces `budget`
    # entirely, which is fine since it only holds `max`).
    "title" = coderModel {
      name = "Title Generator (iGPU)";
      effort = "none";
      capabilities = baseCapabilities // {
        input = [ "text" ];
        tools = false;
        reasoning = baseCapabilities.reasoning // {
          budget = {
            max = 2048;
          };
        };
      };
      limit = {
        context = 8192;
        input = 8192;
        output = 2048;
      };
      body = {
        chat_template_kwargs = {
          enable_thinking = false;
        };
      };
    };
  };

  # The two local providers.
  providers = {
    # Local llama.cpp server (direct, no swap) — used for image models / raw.
    "llama-server" = {
      name = "llama-server (llama.cpp)";
      package = "@opencode/ai/providers/openai-compatible";
      settings = {
        baseURL = "http://192.168.0.3:9931/v1";
        modelsDiscovery = {
          enabled = true;
          modelInfoFormat = "models.dev";
          smartModelName = true;
        };
      };
      models = {
        "llama-server" = {
          name = "llama-server";
          limit = {
            context = 262144;
          };
          capabilities = {
            tools = true;
            input = [
              "text"
              "image"
            ];
            output = [ "text" ];
          };
        };
      };
    };

    # llama-swap — the hot-swapping front door (port 9930). This is the default
    # provider (see `model` in opencode.nix).
    "llama-swap" = {
      name = "LLama Swap";
      package = "@opencode/ai/providers/openai-compatible";
      settings = {
        baseURL = "http://192.168.0.3:9930/v1";
        modelsDiscovery = {
          enabled = true;
          modelInfoFormat = "llama-swap";
          smartModelName = true;
        };
        # Local llama.cpp is slow to warm up (big model load), so the default
        # 300s header timeout kills the connection before headers arrive. `false`
        # disables each timeout (infinite). `timeout` is already unbounded.
        headerTimeout = false;
        chunkTimeout = false;
      };
      models = llamaSwapCoders;
    };
  };
in
{
  inherit
    prettyJson
    isScalar
    baseCapabilities
    reasoningVariants
    coderModel
    llamaSwapCoders
    providers
    ;
}
