# Headless mode: boot to a raw TTY (no desktop.nix stack), autologin as melody.
# Remote access is SSH; llama-swap / opencode are reached over the network.
{ config, lib, ... }:
lib.mkIf (config.meldesktop.mode == "headless") {
  services.getty.autologinUser = "melody";

  # Make the NVIDIA driver usable for CUDA without Xorg. Two things don't
  # happen by default without services.xserver.enable:
  #   1. hardware.nvidia.enabled is derived from "nvidia" ∈ xserver.videoDrivers
  #      (this does NOT start Xorg; that's services.xserver.enable).
  #   2. the nvidia module only adds the kernel modules when xserver.enable is
  #      true, so list them ourselves. NOT nvidia_drm: it would take the console
  #      away from the firmware framebuffer and blank the monitors; CUDA doesn't need it.
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
  ];
}
