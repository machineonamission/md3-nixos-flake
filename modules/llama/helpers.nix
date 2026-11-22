# helpers.nix — llama-swap model builders (the shared macros).
#
# Import once and thread the result through:
#   let llama = import ./helpers.nix { inherit lib pkgs-llama; };
#
#   baseCmd    — the ~40 shared APEX-I-NanoPlus flags (returns a FLAG LIST)
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
  #   Vulkan -> Intel RPL-S iGPU    (mmproj is forced to the CPU — see mmproj)
  llama-cpp = pkgs-llama.llama-cpp.override {
    cudaSupport = true;
    vulkanSupport = true;
  };
  llama-server = lib.getExe' llama-cpp "llama-server";

  # baseCmd — the shared command line for the APEX-I-NanoPlus family, written
  # ONCE. ~40 flags are identical across every model; only the knobs that
  # actually differ become arguments instead of being copied per model:
  #   hf            — remote HF GGUF repo (the weights)
  #   hfFile        — remote HF GGUF filename (targeted with -hff)
  #   ctx           — context window in tokens (262144 default; LFM2.5 = 131072)
  #   np            — parallel slots (3 = pipelined, 1 = full context)
  #   fitt          — fan-in iterations (self-contained MTP head uses 512)
  #   offloadMMProj — true = force mmproj off the iGPU (see mmproj below)
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
      fitt ? 1024,
      offloadMMProj ? false,
      kvqK ? "q8_0",
      kvqV ? "q8_0",
      fitCtx ? 4096,
      specType ? "none",
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

      # --fit-ctx floor for the memory fit. 4096 is llama.cpp's default (i.e.
      # "don't let --fit shrink the context"), so only emit the flag when a model
      # actually sets a higher floor — that keeps every other model's flags clean.
      fitCtxFlags =
        if fitCtx != 4096 then
          [
            "--fit-ctx"
            (toString fitCtx)
          ]
        else
          [ ];

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
      "--repeat-last-n 0"
      "-rea on"
      "--jinja"
      # -ctk / -ctv set the KV-cache quant. Default q8_0 for both. The K cache
      # drives attention stability, so keep it at q8_0; the V cache is less
      # sensitive, so kvqV = "q4_0" halves just the V half of the KV to save VRAM
      # without the all-q4 instability (q4_0 on K is known to be unstable).
      "-ctk ${kvqK}"
      "-ctv ${kvqV}"
    ]
    ++ specTypeFlags
    ++ [
      "--host 0.0.0.0"
      "-np ${toString np}"
      "-cb"
      "--cache-prompt"
      "--cache-ram 32728"
      "--cache-idle-slots"
      "--slots"
      "--threads-http -1"
      "--metrics"
      "--webui"
      "--embedding"
      "-sps 0.5"
      "-v"
      "-lv 4"
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
  # To avoid consuming any of the 16 GB VRAM on the main GPU (RTX 5070 Ti),
  # `device` defaults to "Vulkan0" (Intel iGPU) or can be set to "none" (CPU).
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
    ]
    ++ deviceFlags;

  # selfMtp — speculative decode with a SELF-CONTAINED MTP head: the MTP block
  # lives INSIDE the main GGUF (blk.64.* on the Qwen3.8-27B dense-hybrid family,
  # blk.40 on Qwen3.6-35B-A3B-MTP) so there is NO separate --spec-draft-model.
  # Returns the draft tuning flags for `extra`. Pair with `fitt = 512` (higher fan-in for
  # the self-contained head) in the model literal.
  selfMtp = [
    "--spec-draft-n-max"
    "2"
    "--spec-draft-p-min"
    "0.6"
  ];

  # model — builds a full llama-swap entry for an APEX-I-NanoPlus model. Wraps
  # baseCmd (the shared command) with per-model capabilities + metadata. Every
  # field that varies is an argument, so adding a model is just a literal.
  #   name          — shown in /v1/models
  #   hf            — remote HF GGUF repo (the weights)
  #   hfFile        — remote HF GGUF filename (targeted with -hff)
  #   image         — true = multimodal (has mmproj); sets capabilities.in
  #   ctx           — context window in tokens (262144 default). Big contexts eat
  #                   the KV cache; see kvq.
  #   kvqK          — KV-cache quant for the K cache ("q8_0" default; keep q8_0,
  #                   it drives attention stability)
  #   kvqV          — KV-cache quant for the V cache ("q8_0" default; "q4_0"
  #                   halves just the V half to save VRAM — safer than all-q4)
  #   fitCtx        — --fit-ctx floor: when --fit shrinks to fit VRAM, the least
  #                   context size it will go to (default 4096 = off). Set to keep
  #                   a minimum window, e.g. 131072, instead of offloading layers
  #   quant         — quant label surfaced in metadata
  #   offloadMMProj — true = force mmproj off the iGPU
  #   np            — parallel slots (3 = pipelined, 1 = full context)
  #   fitt          — fan-in iterations (self-contained MTP head uses 512)
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
      kvqK ? "q8_0",
      kvqV ? "q8_0",
      fitCtx ? 4096,
      np ? 1,
      fitt ? 1024,
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
            kvqK
            kvqV
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
    model
    titleModel
    ;
}
