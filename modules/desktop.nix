{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Desktop Environment
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  xdg.portal.enable = true;

  # X Server keyboard layout (moved from hardware.nix after merging xserver.enable)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # OpenRGB lighting (minimal — not all-plugins which is huge)
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
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

  security.pam.services.melody.kwallet.enable = true;

  # services.monado = {
  #   enable = false;
  #   #defaultRuntime = true; # Register as default OpenXR runtime
  # };
  # Quest 3 uses inside-out tracking — there are no lighthouse base stations, so
  # STEAMVR_LH_ENABLE points Monado at a nonexistent lighthouse driver. This is a
  # documented Monado segfault cause (comp_renderer_draw -> compositor_layer_commit),
  # exactly the crash you're seeing. Removed. WiVRn is the Quest 3 runtime here.
  services.wivrn = {
    enable = true;
    openFirewall = true;
    steam.importOXRRuntimes = true;
  };
}
