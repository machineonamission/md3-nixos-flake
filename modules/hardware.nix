{ config, pkgs, lib, inputs, ... }: {
  # Firmware and microcode
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
  hardware.cpu.intel.updateMicrocode = true;

  # Graphics: Intel iGPU for media + NVIDIA RTX 5070 Ti for display
  services.xserver.enable = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # NVIDIA RTX 5070 Ti — bleeding_edge branch + nixos-unstable is the only way to get
  # a Linux 7-compatible driver. See: https://github.com/NixOS/nixpkgs/issues/...
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    branch = "bleeding_edge";
  };
  hardware.nvidia-container-toolkit.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  # NTFS Resurrection (Linux 7.1+ driver) — required for BitLocker HDD access
  boot.supportedFilesystems = [ "ntfs" ];
  programs.fuse.enable = true;
  programs.fuse.userAllowOther = true;

  # Filesystem utilities
  programs.partition-manager.enable = true;
}
