{
  networking = {
    hostName = "MelDesktop3";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  services.cloudflare-warp.enable = true;
}
