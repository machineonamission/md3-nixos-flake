{ config, pkgs, lib, ... }: {
  # Desktop Environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # X Server keyboard layout (moved from hardware.nix after merging xserver.enable)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # OpenRGB lighting (minimal — not all-plugins which is huge)
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb;
    motherboard = "intel";
  };

  # Users & groups
  users.groups.openrgb = { };
  users.users.openrgb = {
    isSystemUser = true;
    group = "openrgb";
    extraGroups = [
      "i2c"
      "input"
    ];
  };
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

  # Fonts
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

  # Flatpak (for apps removed from nixpkgs, e.g. Spotify)
  services.flatpak.enable = true;

  # System locale/time
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
}
