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
  #   and spawns llama-server on 9931 (the ${PORT} macro starts here).
  #
  # The "TIELLL" LLaMA-GUI preset is encoded here as services.llama-swap.settings,
  # which the nix module renders into its own config.yaml. Model is pulled from
  # HuggingFace via llama-server's --hf-model (cached in LLAMA_CACHE).
  services.llama-swap = {
    enable = true;
    port = 9930; # llama-swap front door
    startPort = 9931; # ${PORT} starts here -> llama-server on 9931

    settings = {
      # preset.presets[0].data
      healthCheckTimeout = 500;
      sendLoadingState = true;

      models = {
        "Tiel-Coder-35B-A3B" = {
          name = "Tiel Coder 35B A3B (NanoPlus)";
          aliases = [
            "TIELLL"
            "tierl"
          ];

          # Replace the token placeholder with your HuggingFace token.
          # --hf-model downloads the GGUF into LLAMA_CACHE
          # (the module sets it to /var/cache/llama-swap/huggingface/hub).
          cmd = ''${pkgs-llama.llama-cpp-cuda}/bin/llama-server --hf-model "IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF" --hf-token "REPLACE_WITH_YOUR_HF_TOKEN" --port ''${PORT} --ctx-size 262144 --flash-attn-on --kv-offload --load-mode MMAP --jinja --embeddings --n-gpu-layers -1 --main-gpu 0 --temperature 0.55 --top-k 20 --top-p 0.95 --min-p 0.05 --typical-p 1 --repeat-last-n 0 --repeat-penalty 1 --presence-penalty 0 --frequency-penalty 0 --dry-multiplier 0.1 --dry-base 1.75 --dry-allowed-length 4 --seed -1 --n-threads -1 --n-predict -1'';
        };
      };
    };
  };

  # The module runs llama-swap as a DynamicUser (no group memberships), so it
  # can't open the NVIDIA device nodes (root:video, 660) for CUDA even though
  # it sets PrivateDevices = false. Add the video group to enable GPU.
  systemd.services.llama-swap.supplementaryGroups = [ "video" ];

  /*
    services.ollama = {
      enable = true;
      package = pkgs-llama.ollama-cuda;
    };
  */
}
