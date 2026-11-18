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

  # RDP — remote desktop access to full KDE Plasma over X11 (boot-accessible).
  # Logs in as `melody` via xrdp-sesman's PAM stack (startSession + allowNull).
  #
  # Black-screen fix: the old value ran bare `ksmserver` (the Plasma Session
  # Manager) with no desktop shell and no Qt env, so xrdp's Xorg came up with
  # nothing rendered. `startplasma-x11` is the proper X11 session launcher — it
  # injects QT_PLUGIN_PATH / XDG_DATA_DIRS and then starts ksmserver + the
  # desktop shell. It ships in plasma-workspace (always installed with the
  # desktop), regardless of the local seat being Wayland. This gives a full
  # remote desktop on a virtual X session (a 2nd session, not a mirror of the
  # physical monitors). To mirror the physical monitors you'd need the console
  # to run X11 and xrdp's "existing session" mode instead — see note below.
  #
  # dbus-run-session provides the D-Bus session bus xrdp-sesman lacks (it runs
  # outside systemd), which Plasma requires to start.
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dbus-run-session startplasma-x11";

  # Cloudflare WARP
  services.cloudflare-warp.enable = true;
}
