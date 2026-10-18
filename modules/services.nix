{ config, pkgs, lib, inputs, ... }: {
  # OneDrive sync (uni files) — user-level systemd service
  services.onedrive.enable = true;

  # Services
  services.printing.enable = true;

  # Audio (PipeWire replaces PulseAudio)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Howdy facial recognition (boot-accessible login)
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
        # Skip facial auth on SSH logins (otherwise Howdy tries face recognition, times out, and falls back to password)
        abort_if_ssh = false;
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
  };
  systemd.services."polkit-agent-helper@" = {
    serviceConfig = {
      PrivateDevices = false;
      DevicePolicy = "auto";
      DeviceAllow = [ "" ];
      ProtectHome = false;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_NETLINK"
      ];
    };
  };

  # IR emitter (e.g., for media center remote control)
  services.linux-enable-ir-emitter.enable = true;
}
