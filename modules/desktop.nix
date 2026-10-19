{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Your desktop/lock wallpaper, copied into the store so the pre-login
  # sddm user can read it. The shipped breeze theme points at its own
  # bundled wallpaper, so instead of shipping custom QML we reuse the
  # shipped breeze theme and just write a fresh theme.conf pointing at
  # AURORA.jpg (see ./sddm/aurora-theme.conf).
  auroraTheme = pkgs.runCommand "sddm-aurora-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze $out/share/sddm/themes/aurora
    chmod -R u+w $out/share/sddm/themes/aurora
    sed "s#PLACEHOLDER#${pkgs.kdePackages.plasma-desktop}#" ${./sddm/aurora-theme.conf} > $out/share/sddm/themes/aurora/theme.conf
    cp ${./sddm/AURORA.jpg} $out/share/sddm/themes/aurora/wallpaper.jpg
    chmod a+r $out/share/sddm/themes/aurora/wallpaper.jpg
  '';
in
{
  # Desktop Environment
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "aurora";
  };

  # Put the theme where SDDM looks for it. system.path is a buildEnv over
  # environment.systemPackages (ignoreCollisions = true), so adding the
  # theme there merges its sw/ tree into /run/current-system/sw, where SDDM
  # looks. (environment.etc goes to /etc and is never read by SDDM — that was
  # the reason the first attempt didn't apply.)
  environment.systemPackages = [ auroraTheme ];
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
