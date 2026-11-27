# RDP (normal + saver): a SECOND virtual X11 Plasma session (not a mirror of
# the monitors). startplasma-x11 sets up the Qt env before ksmserver;
# dbus-run-session gives it the session bus xrdp-sesman (outside systemd) lacks.
{ config, lib, ... }:
lib.mkIf config.meldesktop.desktop {
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dbus-run-session startplasma-x11";
}
