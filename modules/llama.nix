{ config, pkgs, lib, inputs, pkgs-llama, ... }: {
  # LLaMA C++ CUDA build from source (uses nixpkgs-unstable with cudaSupport)
  environment.systemPackages = with pkgs-llama; [
    llama-cpp-cuda
  ];
}
