{
  config,
  pkgs,
  inputs,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    #package = config.boot.kernelPackages.nvidiaPackages.production;
    #branch = "production";
  };
  # build llama from source
  #  environment.systemPackages = [
  #    inputs.llama-cpp.packages.${pkgs.system}.cuda
  #  ];
  services.llama-swap = {
    enable = true;
    port = 9930;
  };
}
