{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    # BLEEDING EDGE BRANCH + NIXOS-UNSTABLE (not 26.05) IS ONLY WAY TO GET LINUX 7 COMPATIBLE DRIVER OH MY GOD
    branch = "bleeding_edge";
  };
  hardware.nvidia-container-toolkit.enable = true;
  # build llama from source
  #  environment.systemPackages = [
  #    inputs.llama-cpp.packages.${pkgs.system}.cuda
  #  ];
  services.llama-swap = {
    enable = true;
    port = 9930;
  };
}
