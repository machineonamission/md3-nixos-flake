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

  # RDP — remote desktop access to full KDE Plasma over X11 (boot-accessible)
  # xrdp-sesman runs outside systemd, so no D-Bus session bus is available.
  # We use dbus-run-session to create one for the Plasma session.
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dbus-run-session startplasma-x11";

  # Cloudflare WARP
  services.cloudflare-warp.enable = true;
}
