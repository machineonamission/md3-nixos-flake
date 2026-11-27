# providers.nix — OpenCode providers. The llama-swap model list is generated
# from the shared catalog (modules/llm/models): every model AND every profile becomes
# an OpenCode model with the same id, with reasoning-effort variants.
#
# Discovery is OFF for llama-swap on purpose: it can't produce variants, and it
# lists models without profiles. The catalog already knows everything.
#
#   llama-swap/<id>               -> the spec's default `effort`
#   llama-swap/<id>#low|medium|high
#                                 -> request-body reasoning_effort (thinking ON)
#   llama-swap/<id>#noreasoning   -> chat_template_kwargs.enable_thinking = false:
#                                    no <think> at all. Must be a JSON BOOLEAN,
#                                    llama.cpp rejects a quoted string.
{ lib, catalog }:
let
  host = "192.168.0.3"; # this desktop on the LAN (llama-swap listens on 0.0.0.0)

  efforts = [
    "low"
    "medium"
    "high"
  ];

  # effort "none" also disables the thinking template, otherwise llama.cpp
  # still thinks and just ignores the effort
  effortSettings =
    effort:
    {
      settings.reasoningEffort = effort;
    }
    // lib.optionalAttrs (effort == "none") {
      body.chat_template_kwargs.enable_thinking = false;
    };

  variants = map (e: { id = e; } // effortSettings e) efforts ++ [
    ({ id = "noreasoning"; } // effortSettings "none")
  ];

  toModel =
    s:
    {
      name = if s.kind == "profile" then "Profile: ${s.name}" else s.name;
      type = "chat";
      limit = {
        context = s.ctx;
        input = s.ctx;
        output = s.maxOutput;
      };
      capabilities = {
        input = [ "text" ] ++ lib.optional s.image "image";
        output = [ "text" ];
        inherit (s) tools;
        temperature = true;
        reasoning = {
          supported = true;
          toggle = true;
          budget.max = s.reasoningBudget;
          effort = [ "none" ] ++ efforts;
        };
      };
      inherit variants;
    }
    // effortSettings s.effort;
in
{
  llama-swap = {
    name = "LLama Swap";
    package = "@opencode/ai/providers/openai-compatible";
    settings = {
      baseURL = "http://${host}:${toString catalog.port}/v1";
      modelsDiscovery.enabled = false;
      # Big local models are slow to load, so the default 300 s header timeout
      # kills the connection before headers arrive. false = no timeout.
      # (`timeout` is already unbounded by default.)
      headerTimeout = false;
      chunkTimeout = false;
    };
    models =
      lib.mapAttrs (_: toModel) catalog.models // lib.mapAttrs (_: p: toModel p.spec) catalog.profiles;
  };

  # Plain llama-server on :9931 (not managed by this repo): whatever it serves
  # is found by the opencode-models-discovery plugin.
  llama-server = {
    name = "llama-server (llama.cpp)";
    package = "@opencode/ai/providers/openai-compatible";
    settings = {
      baseURL = "http://${host}:9931/v1";
      modelsDiscovery = {
        enabled = true;
        modelInfoFormat = "models.dev";
        smartModelName = true;
      };
    };
    models.llama-server = {
      name = "llama-server";
      limit.context = 262144;
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
}
