{ config, pkgs, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    #package = config.boot.kernelPackages.nvidiaPackages.production;
    branch = "production";
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  config.services.llama-cpp = {
    enable = true;
    package = (pkgs.llama-cpp.override {
        cudaSupport = true;
        nvidia.acceptLicense = true;
        cudaCapabilities = [ "12.0" ];
        cudaForwardCompat = true;
    });
  };
}
