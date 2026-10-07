{ config, pkgs, ... }:
{
  # X Server
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # OpenRGB lighting (minimal, not all-plugins which is huge)
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb;
    motherboard = "intel";
  };
  users.groups.openrgb = { };
  users.users.openrgb = {
    isSystemUser = true;
    group = "openrgb";
    extraGroups = [
      "i2c"
      "input"
    ];
  };

  # IR emitter
  services.linux-enable-ir-emitter.enable = true;

  # Howdy facial recognition
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

  # Desktop applications
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.kdeconnect.enable = true;
  # OneDrive sync daemon disabled — it watches Nix store paths and triggers constant rebuilds
  # services.onedrive.enable = true;

  # Baloo file indexer: exclude /nix/store to prevent CPU spikes on nixos-rebuild switch
  # (NixOS 26.11 doesn't expose this option yet — handled via systemd override)
  # services.kde.baloo.excludePaths = [ "/nix/store" ];

  # RDP — remote desktop access without GUI login (boot-accessible)
  services.xrdp.enable = true;

  # User configuration
  users.users."melody" = {
    isNormalUser = true;
    description = "Melody";
    extraGroups = [
      "networkmanager"
      "wheel"
      "i2c"
      "input"
    ];
  };

  # Font configuration
  fonts.fontconfig = {
    enable = true;
    antialias = true;
    hinting = {
      enable = true;
      style = "slight";
    };
    subpixel = {
      rgba = "none";
      lcdfilter = "default";
    };
  };

  # Directory environment
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
