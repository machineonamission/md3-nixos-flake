{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Networking
  networking = {
    hostName = "MelDesktop3";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  # SSH — password auth (boot-accessible remote access via SSH + RDP)
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # Cloudflare WARP
  services.cloudflare-warp.enable = true;
}
