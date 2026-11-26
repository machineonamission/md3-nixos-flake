# Firmware, GPUs, bluetooth, filesystems.
{ config, pkgs, ... }:
{
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  services.fwupd.enable = true;

  # Intel iGPU: media decode + the Vulkan device llama-swap / saver mode use.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # RTX 5070 Ti. The X server itself lives in desktop.nix; headless.nix loads
  # the driver for CUDA without it.
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    # Install the CUDA MPS / nvidia-smi / debug tools the stock package leaves
    # in origBin (from https://github.com/paul-wtf/nixos/pull/7).
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
  # GPU access for containers. The assertion wants "nvidia" in
  # xserver.videoDrivers, which is true in every mode, so this is belt-and-braces.
  hardware.nvidia-container-toolkit = {
    enable = true;
    suppressNvidiaDriverAssertion = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  # Linux 7.1+ NTFS driver (BitLocker HDD)
  boot.supportedFilesystems = [ "ntfs" ];

  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };
  programs.partition-manager.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
