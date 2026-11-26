{
  config,
  pkgs,
  lib,
  ...
}:
{
  # ---------------------------------------------------------------------------
  # Base system — the parts that are identical in EVERY mode (normal / saver /
  # headless). Split out of the old desktop.nix so headless still gets the user,
  # fonts, locale, and hardware peripherals without pulling in a display manager
  # or a desktop.
  # ---------------------------------------------------------------------------

  # Users & groups. `melody` must exist in headless mode (ssh, llama-swap, and
  # the opencode service all run as this user), so it lives here, not in the
  # desktop-only module.
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

  # Fonts (fontconfig applies to the TTY in headless mode too)
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

  # System locale / time
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # OpenRGB lighting (talks to the motherboard over i2c; runs headless fine)
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "intel";
  };

  # WiVRn — Quest 3 inside-out tracking runtime. No lighthouse base stations, so
  # STEAMVR_LH_ENABLE would point Monado at a nonexistent driver (a documented
  # segfault: comp_renderer_draw -> compositor_layer_commit). WiVRn is the
  # correct runtime here. Harmless in headless mode (no VR session is started).
  services.wivrn = {
    enable = true;
    openFirewall = true;
    steam.importOXRRuntimes = true;
  };
}
