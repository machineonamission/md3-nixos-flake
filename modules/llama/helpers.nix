# helpers.nix — llama-swap model builders (the shared macros).
#
# Import once and thread the result through:
#   let llama = import ./helpers.nix { inherit lib pkgs-llama; };
#
#   baseCmd    — the shared APEX-I-NanoPlus flags (returns a FLAG LIST)
#   mtpExtra   — separate-draft MTP flags (Occamy / KAT, `repo:file` draft head)
#   model      — full llama-swap entry for a 35B/27B/24B APEX-I-NanoPlus model
#   titleModel — tiny iGPU title-gen model (smaller flag set + ttl)
#
# Everything that varies across models is an ARGUMENT, so adding a model is a
# literal with just its knobs — no flag copying.
{
  lib,
  pkgs-llama,
  ...
}:
let
  # Unified CUDA + Vulkan llama-server. pkgs-llama was imported with cudaSupport
  # + vulkanSupport (flake.nix) so this ONE binary sees BOTH devices:
  #   CUDA   -> NVIDIA RTX 5070 Ti  (the fast card; holds the weights)
  #   Vulkan -> Intel RPL-S iGPU    (hosts title models + separate MTP draft heads)
  llama-cpp = pkgs-llama.llama-cpp.override {
    cudaSupport = true;
    vulkanSupport = true;
  };
  llama-server = lib.getExe' llama-cpp "llama-server";

  # baseCmd — the shared command line for the APEX-I-NanoPlus family, written
  # ONCE. Only the knobs that actually differ become arguments instead of being
  # copied per model:
  #   hf            — remote HF GGUF repo (the weights)
  #   hfFile        — remote HF GGUF filename (targeted with -hff)
  #   ctx           — advertised context window in tokens (131072 default)
  #   np            — parallel slots (1 = full context, avoids KV duplication)
  #   fitt          — fit target margin in MiB (self-contained MTP head uses 512)
  #   offloadMMProj — true = offload mmproj to Vulkan0; false = keep on CPU
  #   fitCtx        — --fit-ctx floor (defaults to ctx; omits -c so --fit on can
  #                   trim context down to this floor before offloading layers)
  #   specType      — speculative decoding type ("none" or "draft-mtp")
  #   extra         — raw flags, appended LAST so per-model flags sit next to
  #                   the model that needs them
  # Returns a LIST of flags so callers can concat before joining.
  baseCmd =
    {
      hf,
      hfFile ? null,
      ctx ? 262144,
      np ? 1,
      fitt ? 256,
      offloadMMProj ? false,
      kvq ? "q8_0",
      fitCtx ? -1,
      specType ? null,
      extra ? [ ],
    }:
    let
      # HuggingFace model file targeting:
      # If hfFile is specified, pass -hff so llama.cpp loads that exact GGUF
      # rather than auto-picking sidecars (such as dflash or mmproj) as the primary model.
      hfFileFlags =
        if hfFile != null then
          [
            "-hff"
            hfFile
            "--mmproj-auto"
          ]
        else
          [ ];

      # Speculative decoding type:
      specTypeFlags =
        if specType != null && specType != "" then
          [
            "--spec-type"
            specType
          ]
        else
          [ ];

      # Leave -c unset when fitCtx is active so `--fit on` adjusts context from
      # the model's native max down to the `--fit-ctx` floor instead of forcing
      # layer offloading onto system RAM.
      fitCtxFlags =
        if fitCtx != null && fitCtx != -1 then
          [
            "--fit-ctx"
            (toString fitCtx)
          ]
        else
          [ "-c ${toString ctx}" ];

      # Image models load the small mmproj ON THE CPU. The Intel iGPU / Vulkan0
      # path garbles every image model, every time, so we never offload it. Text
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
    ]
    ++ hfFileFlags
    ++ [
      "--image-min-tokens 1024"
      "--load-mode auto"
      "--kv-unified"
      "-t 8"
      "-tb 16"
      "--poll 50"
      "-dev CUDA0"
      "-ngl auto"
      "-mg 0"
      "-fa on"
      "--repack"
      "--fit on"
      # "--prio 2"
    ]
    ++ fitCtxFlags
    ++ [
      "-fitt ${toString fitt}"
    ]
    ++ mmproj
    ++ [
      "--temp 0.6"
      "--top-k 20"
      "--top-p 0.95"
      "--min-p 0.05"
      "-rea on"
      "--jinja"
      # -ctk / -ctv set the KV-cache quant. Flat q8_0 for both K and V — this is
      # the only combo that ships a CUDA FlashAttention kernel. Asymmetric
      # (q8_0-q4_0) falls back to f16 conversion and is slow, so both stay q8_0.
      "--cache-type-k ${kvq}"
      "--cache-type-v ${kvq}"
    ]
    ++ specTypeFlags
    ++ [
      "--host 0.0.0.0"
      "-np ${toString np}"
      "-cb"
      "--cache-prompt"
      "--cache-ram -1"
      "--cache-idle-slots"
      "--slots"
      "--threads-http -1"
      "--metrics"
      "--webui"
      "-lv 3"
      "--log-colors on"
      "--log-prefix"
      "--log-timestamps"
      "--no-warmup"
      # --n-predict hard-caps tokens per response. -1 (llama.cpp default) would
      # run until the context window; 32768 matches metadata.max_output_tokens
      # so both layers agree on the ceiling.
      "--n-predict"
      "32768"
      # --reasoning-budget is the circuit breaker for the thinking-loop doomloop:
      # a hard token cap on the internal-thinking phase so it can never eat the
      # whole context window. --reasoning-effort medium is the vendor default;
      # this is the hard ceiling on top of it.
      "--reasoning-budget"
      "16384"
      # ---- SAMPLING (vendor APEX-I-NanoPlus defaults) -----------------------
      # repeat/freq/presence penalties are DISABLED — vendor requirement for
      # code: repeat_penalty must be 1.0 and presence/frequency 0.0, else `{` /
      # `=` / indentation tokens get penalized and the model swaps chars.
      "--repeat-penalty"
      "1.0"
      "--presence-penalty"
      "0.0"
      "--frequency-penalty"
      "0.0"
    ]
    ++ extra;

  # mtpExtra — speculative decode with a SEPARATE draft head.
  # HuggingFace draft models are targeted via `--spec-draft-hf <repo>` and `--spec-draft-model <file>`.
  # Defaults to "Vulkan0" (Intel iGPU) with q8_0 draft KV cache so 100% of the
  # RTX 5070 Ti's 16 GB VRAM stays reserved for the main coder.
  # Returns the flag list for `model` to append.
  #   repo          — the model's HF repo (holds the draft head too)
  #   file          — the standalone draft .gguf filename
  #   specDraftNMax — max draft tokens (default 2)
  #   draftMax      — backwards-compatibility alias for specDraftNMax
  #   device        — device for the draft model ("Vulkan0", "none"/"cpu", or "CUDA0")
  mtpExtra =
    {
      repo,
      file,
      specDraftNMax ? 2,
      draftMax ? null,
      device ? "Vulkan0",
    }:
    let
      nMax = if draftMax != null then draftMax else specDraftNMax;
      deviceFlags =
        if device == "Vulkan0" || device == "vulkan" || device == "igpu" then
          [
            "--spec-draft-device"
            "Vulkan0"
            "--spec-draft-ngl"
            "all"
          ]
        else if device == "none" || device == "cpu" then
          [
            "--spec-draft-device"
            "none"
            "--spec-draft-ngl"
            "0"
          ]
        else if device == "cuda" || device == "CUDA0" then
          [
            "--spec-draft-device"
            "CUDA0"
            "--spec-draft-ngl"
            "all"
          ]
        else
          [
            "--spec-draft-device"
            device
          ];
    in
    [
      "--spec-draft-hf"
      repo
      "--spec-draft-model"
      file
      "--spec-draft-n-max"
      (toString nMax)
      "-ctkd"
      "q8_0"
      "-ctvd"
      "q8_0"
    ]
    ++ deviceFlags;

  # selfMtp — speculative decode with a SELF-CONTAINED MTP head: the MTP block
  # lives INSIDE the main GGUF (blk.64.* on the Qwen3.8-27B dense-hybrid family,
  # blk.40 on Qwen3.6-35B-A3B-MTP) so there is NO separate --spec-draft-model.
  # Returns the draft tuning flags for `extra`. Pair with `fitt = 512` (higher fan-in for
  # the self-contained head) in the model literal.
  selfMtp = [
    "--spec-draft-n-max"
    "4"
  ];

  # valV3 — the 27B dense-hybrid VAL-APEX-NanoPlus-V3 family. All share:
  #   * quant = "VAL-APEX-I-NanoPlus-V3" (~11–13 GB, fits 16 GB GPUs)
  #   * a self-contained MTP head (blk.64.*) => extra = selfMtp (speculative decode)
  #   * fitt = 512 (higher fan-in for that head)
  # Callers pass only the bits that differ (name / repo / image / context).
  # Arete is text-only (no MTP head), so it stays a plain `model` literal.
  valV3 =
    {
      name,
      hf,
      hfFile,
      image ? true,
      ctx ? 131072,
      kvq ? "q8_0",
      fitCtx ? ctx,
      fitt ? 512,
    }:
    model {
      inherit
        name
        hf
        hfFile
        image
        ctx
        kvq
        fitCtx
        fitt
        ;
      quant = "VAL-APEX-I-NanoPlus-V3";
      extra = selfMtp;
    };

  # model — builds a full llama-swap entry for an APEX-I-NanoPlus model. Wraps
  # baseCmd (the shared command) with per-model capabilities + metadata. Every
  # field that varies is an argument, so adding a model is just a literal.
  #   name          — shown in /v1/models
  #   hf            — remote HF GGUF repo (the weights)
  #   hfFile        — remote HF GGUF filename (targeted with -hff)
  #   image         — true = multimodal (has mmproj); sets capabilities.in
  #   ctx           — advertised context window in tokens (131072 default)
  #   kvq           — KV-cache quant for both K and V ("q8_0" default; flat q8_0
  #                   is required — asymmetric q8-q4 has no FA kernel and is slow)
  #   fitCtx        — --fit-ctx floor (defaults to ctx): minimum context size
  #                   --fit will shrink to before offloading layers to CPU
  #   quant         — quant label surfaced in metadata
  #   offloadMMProj — true = force mmproj onto Vulkan0
  #   np            — parallel slots (1 = full context)
  #   fitt          — fit target margin in MiB (self-contained MTP head uses 512)
  #   extra         — raw flags appended to the base command
  #   mtp           — optional fn repo -> flags for a separate MTP draft head
  #   specType      — defaults to "draft-mtp" when mtp or selfMtp is used, else "none"
  model =
    {
      name,
      hf,
      hfFile ? null,
      image ? false,
      ctx ? 262144,
      quant ? "APEX-I-NanoPlus",
      offloadMMProj ? false,
      kvq ? "q8_0",
      fitCtx ? null,
      np ? 1,
      fitt ? 256,
      extra ? [ ],
      mtp ? null,
      specType ? (if (mtp != null || extra == selfMtp) then "draft-mtp" else "none"),
    }:
    {
      inherit name;
      # base command ++ separate-draft MTP flags (if any) ++ extra overrides
      cmd = lib.concatStringsSep " " (
        baseCmd {
          inherit
            hf
            hfFile
            ctx
            kvq
            fitCtx
            np
            fitt
            offloadMMProj
            specType
            extra
            ;
        }
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

      # max_input_tokens == the context window; max_output_tokens drives
      # OpenCode's Output limit (32768 here). These surface verbatim in
      # meta.llamaswap so the models-discovery plugin can set Input/Output
      # limits (llama-swap doesn't emit them by default).
      metadata = {
        hf_repo = hf;
        inherit quant;
        max_input_tokens = ctx;
        max_output_tokens = 32768;
      }
      // lib.optionalAttrs (hfFile != null) { hf_file = hfFile; };
    };

  # titleModel — tiny iGPU title-gen model. These don't need the full APEX-I-
  # NanoPlus flag set; they share ~90% of a small baseline and differ only in
  # repo / context / reasoning budget / presence penalty. ttl = unload after
  # 120s idle so the title model doesn't stay resident and hog RAM.
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
      cmd = lib.concatStringsSep " " ([
        "${llama-server}"
        "--port \${PORT}"
        "-hf ${hf}"
        "--temp 0.6"
        "--top-k 20"
        "--top-p 0.95"
        "--min-p 0.0"
        "--presence-penalty ${toString presencePenalty}"
        "-c ${toString ctx}"
        "--reasoning-budget ${toString reasoningBudget}"
        "--n-predict 2048"
        "--jinja"
        "--host 0.0.0.0"
        "-np 1"
        "-t 4"
        "-tb 8"
        "--no-warmup"
        "--device Vulkan0"
      ]);
      checkEndpoint = "/health";
      ttl = 120;
      metadata = {
        max_input_tokens = ctx;
        max_output_tokens = 2048;
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
    baseCmd
    mtpExtra
    selfMtp
    valV3
    model
    titleModel
    ;
}
