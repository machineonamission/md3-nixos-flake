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
  #
  # `startplasma-x11` is only exported when the local seat runs an X11 session;
  # this box runs Wayland, so only `startplasma-wayland` is exported and the
  # X11 launcher was missing (xrdp started Xorg with no desktop = black screen).
  # `ksmserver` is the Plasma session manager that launcher runs under, and it's
  # always exported — use it directly.
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dbus-run-session ksmserver";

  # Cloudflare WARP
  services.cloudflare-warp.enable = true;
}
