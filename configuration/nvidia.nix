{ config, pkgs, ... }: {
  # NVIDIA video driver — best performer for LLM inference on RTX 5070 Ti (Blackwell GB202)
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    branch = "latest";
  };

  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # CUDA 12.9 for LLM inference (llama.cpp, etc.)

  environment.localBinInPath = true;
}
