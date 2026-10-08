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
    branch = "production";
  };

  services.llama-cpp = {
    enable = true;
    # Inject the flake's optimized package override here
    package = inputs.llama-cpp.packages.${pkgs.system}.cuda;
  };
}
