# helpers.nix — turn a model spec (modules/llm) into a llama-swap entry.
#
#   entry     — spec -> { name; cmd; checkEndpoint; capabilities; metadata; ... }
#   llama-cpp — the unified CUDA + Vulkan build every entry runs
{ lib, pkgs-llama }:
let
  # One binary that sees BOTH devices:
  #   CUDA0   -> RTX 5070 Ti (weights of the main coders)
  #   Vulkan0 -> Intel iGPU  (title models + separate MTP draft heads)
  llama-cpp = pkgs-llama.llama-cpp.override {
    cudaSupport = true;
    vulkanSupport = true;
  };
  server = lib.getExe' llama-cpp "llama-server";

  # Where a SEPARATE draft head runs. igpu keeps 100% of the RTX VRAM for the coder.
  draftDevice = {
    igpu = [ "--spec-draft-device Vulkan0 --spec-draft-ngl all" ];
    cpu = [ "--spec-draft-device none --spec-draft-ngl 0" ];
    cuda = [ "--spec-draft-device CUDA0 --spec-draft-ngl all" ];
  };

  # MTP speculative-decode flags. `mtp` is one of:
  #   null   — no speculative decoding
  #   "self" — MTP head embedded in the main GGUF (e.g. blk.64.*)
  #   { file; repo ? <model repo>; nMax ? 2; device ? "igpu"; }
  #          — separate draft .gguf
  mtpFlags =
    hf: mtp:
    if mtp == null then
      [ ]
    else if mtp == "self" then
      [ "--spec-draft-n-max 4" ]
    else
      [
        "--spec-draft-hf ${mtp.repo or hf}"
        "--spec-draft-model ${mtp.file}"
        "--spec-draft-n-max ${toString (mtp.nMax or 2)}"
        "-ctkd q8_0 -ctvd q8_0"
      ]
      ++ draftDevice.${mtp.device or "igpu"};

  capabilities = s: {
    "in" = [ "text" ] ++ lib.optional s.image "image";
    out = [ "text" ];
    inherit (s) tools;
    context = s.ctx;
  };

  # Main coder on the RTX (CUDA0), full APEX-I-NanoPlus flag set.
  coder = s: {
    inherit (s) name;
    cmd = toString (
      [
        server
        "--port \${PORT}"
        "-hf ${s.hf}"
      ]
      ++ lib.optional (s.hfFile != null) "-hff ${s.hfFile} --mmproj-auto"
      ++ [
        "--image-min-tokens 1024"
        "--load-mode auto"
        "-t 8 -tb 16"
        "--poll 50"
        "-dev CUDA0 -ngl auto -mg 0"
        "-fa on"
        "--repack"
        "--fit on"
        (if s.fitCtx != null then "--fit-ctx ${toString s.fitCtx}" else "-c ${toString s.ctx}")
        "-fitt ${toString s.fitt}"
        (if s.offloadMMProj then "--mmproj-offload --mmproj-device Vulkan0" else "--no-mmproj-offload")
        # vendor sampling defaults
        "--temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.05"
        "-rea on"
        "--jinja"
        "--cache-type-k ${s.kvq} --cache-type-v ${s.kvq}"
        "--spec-type ${if s.mtp != null then "draft-mtp" else "none"}"
        "--host 0.0.0.0"
        "-np ${toString s.np}"
        "-cb --cache-prompt --cache-ram -1 --cache-idle-slots"
        "--slots --threads-http -1 --metrics --webui"
        "-lv 3 --log-colors on --log-prefix --log-timestamps"
        "--no-warmup"
        "--n-predict ${toString s.maxOutput}"
        "--reasoning-budget ${toString s.reasoningBudget}"
        # penalties OFF (vendor requirement for code: otherwise `{` `=` and
        # indentation tokens get penalised and the model swaps characters)
        "--repeat-penalty 1.0 --presence-penalty 0.0 --frequency-penalty 0.0"
      ]
      ++ s.extra
      ++ mtpFlags s.hf s.mtp
    );
    checkEndpoint = "/health";
    capabilities = capabilities s;
    # surfaced verbatim in /v1/models meta.llamaswap
    metadata = {
      hf_repo = s.hf;
      inherit (s) quant;
      max_input_tokens = s.ctx;
      max_output_tokens = s.maxOutput;
    }
    // lib.optionalAttrs (s.hfFile != null) { hf_file = s.hfFile; };
  };

  # Tiny always-ready title model on the iGPU; ttl unloads it after 120 s idle.
  title = s: {
    inherit (s) name;
    cmd = toString [
      server
      "--port \${PORT}"
      "-hf ${s.hf}"
      "--temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.0"
      "--presence-penalty ${s.presencePenalty}"
      "-c ${toString s.ctx}"
      "--reasoning-budget ${toString s.reasoningBudget}"
      "--n-predict ${toString s.maxOutput}"
      "--jinja"
      "--host 0.0.0.0"
      "-np 1 -t 4 -tb 8"
      "--no-warmup"
      "--device Vulkan0"
    ];
    checkEndpoint = "/health";
    ttl = 120;
    metadata = {
      max_input_tokens = s.ctx;
      max_output_tokens = s.maxOutput;
    };
    capabilities = capabilities s;
  };
in
{
  inherit llama-cpp;
  entry = s: { inherit coder title; }.${s.kind} s;
}
