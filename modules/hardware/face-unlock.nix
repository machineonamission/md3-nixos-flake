# Howdy face unlock (IR camera) for login, sudo, polkit, SDDM, KDE lock screen.
{
  services.linux-enable-ir-emitter.enable = true; # IR emitter for howdy's camera

  services.howdy = {
    enable = true;
    control = "sufficient";
    settings = {
      video = {
        device_path = "/dev/video2";
        show_window = true;
      };
      core = {
        detection_notice = true;
        # true = skip howdy when SSH_CONNECTION etc. is set (sudo over ssh)
        abort_if_ssh = true;
      };
    };
  };
  security.pam.howdy = {
    enable = true;
    control = "sufficient";
  };
  security.pam.services = {
    kde.howdy.enable = true;
    sddm.howdy.enable = true;
    polkit-1.howdy.enable = true;
    # No camera in front of a remote login.
    sshd.howdy.enable = false;
  };
  # Let the sandboxed polkit helper reach the camera for howdy.
  systemd.services."polkit-agent-helper@".serviceConfig = {
    PrivateDevices = false;
    DevicePolicy = "auto";
    DeviceAllow = [ "" ];
    ProtectHome = false;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_NETLINK"
    ];
  };
}
