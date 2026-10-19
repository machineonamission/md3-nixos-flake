{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Custom SDDM greeter that matches the Plasma lock screen: full-screen
  # AURORA wallpaper + centered clock/avatar/password bar. Built from
  # ./modules/sddm/aurora (a copy of the 6.8.0 breeze theme repointed at
  # AURORA.jpg). The wallpaper is copied into the store so the sddm user can
  # read it before login.
  sddmAuroraTheme = pkgs.runCommand "sddm-aurora-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${./sddm/aurora} $out/share/sddm/themes/aurora
  '';
in
{
  # Desktop Environment
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "aurora";
  };

  # Place the custom "aurora" SDDM theme into the store so SDDM can load it
  # before login (needs to be world-readable; the bundled breeze wallpaper
  # isn't the one we want).
  environment.etc."share/sddm/themes/aurora" = {
    source = "${sddmAuroraTheme}/share/sddm/themes/aurora";
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
