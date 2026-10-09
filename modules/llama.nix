{ config, pkgs, lib, inputs, pkgs-llama, ... }: {
  # LLaMA C++ CUDA build from source (uses nixpkgs-unstable with cudaSupport)
  environment.systemPackages = with pkgs-llama; [
    llama-cpp-cuda
  ];

    # LLaMA Swap — model swapping for local LLM serving (port 9930)
  services.llama-swap = {
    enable = true;
    port = 9930;
  };

  services.ollama = {
    enable = true;
    package = pkgs-llama.ollama-cuda;
  };
}
