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
  services.llama-swap =
    let
      llama-cpp = pkgs.llama-cpp-cuda;
      llama-server = lib.getExe' llama-cpp "llama-server";
    in
    {
      enable = true;
      port = 9930; # llama-swap front door
      # startPort = 9931; # ${PORT} starts here -> llama-server on 9931

      settings = {
        # preset.presets[0].data
        healthCheckTimeout = 500;
        sendLoadingState = true;

        models = {
          "Tiel-Coder-35B-A3B" = {
            name = "Tiel Coder 35B A3B (NanoPlus)";
            aliases = [
              "Tiel"
              "tiel"
              "tiel coder"
            ];

            # --hf-token "REPLACE_WITH_YOUR_HF_TOKEN"
            cmd = ''${llama-server} --port ''${PORT} -hf IsValorum/Tiel-Coder-35B-A3B-APEX-I-NanoPlus-GGUF --image-min-tokens 1024 -c 262144 -b 2048 -ub 512 --load-mode auto -cram 16384 -cms 2048 --poll 50 -ngl auto -mg 0 -fa on -kvo --repack --op-offload -fit on -fitt 512 -fitc 131072 --no-mmproj-offload --temp 0.55 --top-k 20 --top-p 0.95 --min-p 0.05 --repeat-last-n 0 --dry-multiplier 0.1 --dry-allowed-length 4 -rea on --jinja -ctk q8_0 -ctv q8_0 --kv-unified --spec-type none --host 0.0.0.0 -np 3 -cb --cache-prompt --cache-idle-slots --slots -to 3600 --threads-http -1 --metrics --webui --embedding -sps 0.1 -v -lv 4 --log-colors on --log-prefix --log-timestamps --no-warmup'';
            # --slot-save-path /home/melody/LLama-GUI/slots 
          };
        };
      };
    };

  # The module runs llama-swap as a DynamicUser (no group memberships), so it
  # can't open the NVIDIA device nodes (root:video, 660) for CUDA even though
  # it sets PrivateDevices = false. Add the video group to enable GPU.
  # systemd.services.llama-swap.supplementaryGroups = [ "video" ];

  /*
    services.ollama = {
      enable = true;
      package = pkgs-llama.ollama-cuda;
    };
  */
}
