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

  # Graphics: Intel iGPU for media + NVIDIA RTX 5070 Ti for display.
  #
  # NOTE: the X server (services.xserver) is NOT declared here — it lives in
  # desktop.nix, which is imported only in normal / saver mode. In headless mode
  # there is no Xorg: the dGPU drives the raw TTY via its modesetting framebuffer
  # (a few MB of VRAM), and the rest of the card is free for CUDA compute.
  # `hardware.nvidia.modesetting` below stays enabled in ALL modes: it is what
  # lets the dGPU drive the console (TTY) without the proprietary driver.
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
    # branch = "bleeding_edge";
    # https://github.com/paul-wtf/nixos/pull/7/changes
    package = config.boot.kernelPackages.nvidiaPackages.latest.overrideAttrs (old: {
      postInstall = toString old.postInstall + ''
        for i in nvidia-cuda-mps-control nvidia-cuda-mps-server nvidia-smi nvidia-debugdump nvidia-powerd; do
          if [ -e $bin/origBin/$i ]; then
            install -Dm755 $bin/origBin/$i $bin/bin/$i
            patchelf --set-rpath $out/lib:$libPath $bin/bin/$i
            patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $bin/bin/$i
          fi
        done
      '';
    });
  };
  # nvidia-container-toolkit — gives containers access to the NVIDIA GPU.
  # The nvidia driver itself is present in ALL modes via hardware.nvidia
  # (modesetting + the package override below). In desktop modes the driver
  # assertion is satisfied by services.xserver.videoDrivers; in headless mode
  # there is no X server, so we suppress the assertion — the driver is still
  # there, it's just not exposed through Xorg.
  hardware.nvidia-container-toolkit = {
    enable = true;
    suppressNvidiaDriverAssertion = true;
  };

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
  programs.appimage = {
    binfmt = true;
    enable = true;

  };
}
