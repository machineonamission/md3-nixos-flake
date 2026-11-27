# RTX 5070 Ti: driver + GPU access for containers (all modes). The X server
# itself lives in desktop/plasma.nix; modes/headless.nix loads the driver for
# CUDA without it.
{ config, ... }:
{
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
}
