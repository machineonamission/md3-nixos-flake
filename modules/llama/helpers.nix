# helpers.nix — builders that turn a short model spec into a llama-swap entry.
#
#   model      — a main coder on the RTX (CUDA0), full APEX-I-NanoPlus flag set
#   valV3      — `model` preset for the Qwen3.8-27B VAL-APEX-I-NanoPlus-V3 family
#   titleModel — a tiny title-generation model on the Intel iGPU (Vulkan0)
#   llama-cpp  — the unified CUDA + Vulkan build every entry runs
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

  # Each is used twice (CLI cap + the metadata OpenCode reads), so defined once.
  maxOutput = 32768;
  titleMaxOutput = 2048;

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

  # Arguments (only name + hf are required):
  #   hfFile        — exact GGUF in the repo (-hff), so sidecars (dflash, mmproj)
  #                   are never auto-picked as the primary model
  #   image         — multimodal; only changes the advertised capabilities. mmproj
  #                   stays on the CPU: Intel ANV Vulkan garbles clip_encode.
  #   ctx           — context window (passed as -c, advertised to OpenCode)
  #   fitCtx        — if set, -c is omitted and `--fit on` may shrink context to
  #                   this floor before it offloads layers to system RAM
  #   fitt          — --fit target margin in MiB (embedded MTP heads want 512)
  #   kvq           — KV-cache quant for K and V. Keep them equal: only symmetric
  #                   q8_0 has a CUDA FlashAttention kernel.
  #   np            — parallel slots (1 = full context, no KV duplication)
  #   quant         — label surfaced in metadata
  #   mtp           — see mtpFlags
  #   extra         — raw flags appended at the end
  model =
    {
      name,
      hf,
      hfFile ? null,
      image ? false,
      ctx ? 262144,
      fitCtx ? null,
      mtp ? null,
      fitt ? (if mtp == "self" then 512 else 256),
      kvq ? "q8_0",
      np ? 1,
      quant ? "APEX-I-NanoPlus",
      offloadMMProj ? false,
      extra ? [ ],
    }:
    {
      inherit name;
      cmd = toString (
        [
          server
          "--port \${PORT}"
          "-hf ${hf}"
        ]
        ++ lib.optional (hfFile != null) "-hff ${hfFile} --mmproj-auto"
        ++ [
          "--image-min-tokens 1024"
          "--load-mode auto"
          "-t 8 -tb 16"
          "--poll 50"
          "-dev CUDA0 -ngl auto -mg 0"
          "-fa on"
          "--repack"
          "--fit on"
          (if fitCtx != null then "--fit-ctx ${toString fitCtx}" else "-c ${toString ctx}")
          "-fitt ${toString fitt}"
          (if offloadMMProj then "--mmproj-offload --mmproj-device Vulkan0" else "--no-mmproj-offload")
          # vendor sampling defaults
          "--temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.05"
          "-rea on"
          "--jinja"
          "--cache-type-k ${kvq} --cache-type-v ${kvq}"
          "--spec-type ${if mtp != null then "draft-mtp" else "none"}"
          "--host 0.0.0.0"
          "-np ${toString np}"
          "-cb --cache-prompt --cache-ram -1 --cache-idle-slots"
          "--slots --threads-http -1 --metrics --webui"
          "-lv 3 --log-colors on --log-prefix --log-timestamps"
          "--no-warmup"
          "--n-predict ${toString maxOutput}"
          # hard cap on the thinking phase so a reasoning doom-loop can't eat the context
          "--reasoning-budget 16384"
          # penalties OFF (vendor requirement for code: otherwise `{` `=` and
          # indentation tokens get penalised and the model swaps characters)
          "--repeat-penalty 1.0 --presence-penalty 0.0 --frequency-penalty 0.0"
        ]
        ++ extra
        ++ mtpFlags hf mtp
      );
      checkEndpoint = "/health";
      capabilities = {
        "in" = [ "text" ] ++ lib.optional image "image";
        out = [ "text" ];
        tools = true;
        context = ctx;
      };
      # surfaced verbatim in /v1/models meta.llamaswap; the OpenCode
      # models-discovery plugin reads the token limits from here
      metadata = {
        hf_repo = hf;
        inherit quant;
        max_input_tokens = ctx;
        max_output_tokens = maxOutput;
      }
      // lib.optionalAttrs (hfFile != null) { hf_file = hfFile; };
    };

  # 27B dense hybrid, ~11–13 GB: won't fully fit 16 GB VRAM, so a 128K --fit-ctx
  # floor lets --fit spend VRAM on layers instead of KV cache. Embedded MTP head.
  valV3 =
    args:
    model (
      {
        quant = "VAL-APEX-I-NanoPlus-V3";
        image = true;
        ctx = 131072;
        fitCtx = 131072;
        mtp = "self";
      }
      // args
    );

  # Tiny always-ready title models on the iGPU; ttl unloads them after 120 s idle.
  # presencePenalty is a STRING because Nix renders floats as "1.500000".
  titleModel =
    {
      name,
      hf,
      ctx,
      reasoningBudget,
      presencePenalty,
    }:
    {
      inherit name;
      cmd = toString [
        server
        "--port \${PORT}"
        "-hf ${hf}"
        "--temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.0"
        "--presence-penalty ${presencePenalty}"
        "-c ${toString ctx}"
        "--reasoning-budget ${toString reasoningBudget}"
        "--n-predict ${toString titleMaxOutput}"
        "--jinja"
        "--host 0.0.0.0"
        "-np 1 -t 4 -tb 8"
        "--no-warmup"
        "--device Vulkan0"
      ];
      checkEndpoint = "/health";
      ttl = 120;
      metadata = {
        max_input_tokens = ctx;
        max_output_tokens = titleMaxOutput;
      };
      capabilities = {
        "in" = [ "text" ];
        out = [ "text" ];
        tools = false;
        context = ctx;
      };
    };
in
{
  inherit
    llama-cpp
    model
    valV3
    titleModel
    ;
}
