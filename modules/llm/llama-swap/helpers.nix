# helpers.nix — turn a model spec (modules/llm/models) into a llama-swap entry.
#
#   entry     — spec -> { name; cmd; checkEndpoint; capabilities; metadata; ... }
#   llama-cpp — the unified CUDA + Vulkan build every entry runs
{
  lib,
  pkgs-llama,
  llama-cpp-src, # flake input `llama-cpp` (master, flake = false)
}:
let
  # One binary that sees BOTH devices:
  #   CUDA0   -> RTX 5070 Ti (weights of the main coders)
  #   Vulkan0 -> Intel iGPU  (title models + separate MTP draft heads)
  # Built from source with upstream's own Nix expression (it tracks the tree, and
  # its web UI uses importNpmLock, so bumps never need a hash update). CUDA arch
  # comes from pkgs-llama's cudaCapabilities ("12.0").
  upstream = pkgs-llama.callPackage "${llama-cpp-src}/.devops/nix/scope.nix" {
    llamaVersion = "0-unstable-${lib.substring 0 8 llama-cpp-src.lastModifiedDate}";
  };
  llama-cpp =
    (upstream.llama-cpp.override {
      useCuda = true;
      useVulkan = true;
    }).overrideAttrs
      (old: {
        cmakeFlags = old.cmakeFlags ++ [
          # Upstream's expression builds ONE generic CPU backend; inside the Nix
          # sandbox that means no AVX2/AVX-VNNI, which cripples the CPU voice model.
          # Build every CPU variant and pick at runtime (same as nixpkgs).
          (lib.cmakeBool "GGML_CPU_ALL_VARIANTS" true)
          (lib.cmakeBool "GGML_BACKEND_DL" true)
          (lib.cmakeFeature "GGML_BACKEND_DIR" "${placeholder "out"}/bin")
          # shown by `llama-server --version` and /props
          (lib.cmakeFeature "LLAMA_BUILD_COMMIT" llama-cpp-src.shortRev)
        ];
      });
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
  # Home Assistant voice model. ttl and VRAM claim are set in llama-swap/default.nix
  # from the spec (presets.nix voiceModel): the CPU one unloads after 600 s idle.
  # Benchmarked 2026-11-27 on the real HA Assist request (~7.8k-token prompt,
  # 50 tools): the iGPU is ~2x SLOWER than the CPU here (Qwen3.5-4B: Vulkan0
  # 48 t/s prefill / 4.6 t/s gen vs CPU 143 / 11), and it is busy rendering the
  # desktop/video in saver mode anyway, so this deliberately avoids it.
  # Pinning to the P-cores is worth ~20% generation speed. ngram-mod speculation
  # is lossless and ~5% faster (tool-call JSON repeats names from the prompt); a
  # Qwen3.5-0.8B draft model was slower (≈0% acceptance), no MTP head in the GGUF.
  #
  # device = "cuda": the same model fully on the RTX, for when no coder holds it
  # (preloaded at startup; any coder evicts it via the capacity router).
  # -rea off on BOTH: HA sends enable_thinking=true + reasoning_effort=low so that a
  # warm coder (Tiel is reasoning-mandatory and stops calling tools without it)
  # thinks a little; these voice models must ignore that and stay non-thinking.
  voice = s: {
    inherit (s) name;
    cmd = toString (
      lib.optionals (s.device == "cpu") [
        (lib.getExe' pkgs-llama.util-linux "taskset")
        "-c ${s.cpus}"
      ]
      ++ [
        server
        "--port \${PORT}"
        "-hf ${s.hf}"
        "--no-mmproj"
      ]
      ++ (
        if s.device == "cuda" then
          [ "-dev CUDA0 -ngl all -t 4 -tb 8" ]
        else
          [
            "--device none -ngl 0"
            "-t ${toString s.threads} -tb ${toString s.batchThreads}"
          ]
      )
      ++ [
        "-c ${toString s.ctx}"
        "-np 1"
        "-fa on"
        "--jinja"
        "-rea off --reasoning-budget 0"
        "--n-predict ${toString s.maxOutput}"
        # HA's Assist prompt + tool list is a static ~6-8k-token prefix (live
        # state comes through the GetLiveContext tool), so with the prompt cache
        # every turn after the first is a few-token prefill.
        "--cache-prompt --cache-ram -1"
        "--spec-type ngram-mod"
        "--host 0.0.0.0"
        "--no-warmup"
      ]
      ++ s.extra
    );
    checkEndpoint = "/health";
    metadata = {
      hf_repo = s.hf;
      max_input_tokens = s.ctx;
      max_output_tokens = s.maxOutput;
    };
    capabilities = capabilities s;
  };
in
{
  inherit llama-cpp;
  entry = s: { inherit coder title voice; }.${s.kind} s;
}
