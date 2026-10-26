{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # Firmware and microcode
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
  hardware.cpu.intel.updateMicrocode = true;

  # Graphics: Intel iGPU for media + NVIDIA RTX 5070 Ti for display
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # NVIDIA RTX 5070 Ti — bleeding_edge branch + nixos-unstable is the only way to get
  # a Linux 7-compatible driver. See: https://github.com/NixOS/nixpkgs/issues/...
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

  # Programs: fuse, partition-manager, nix-ld
  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };
  programs.partition-manager.enable = true;
  programs.nix-ld.enable = true;
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
}
