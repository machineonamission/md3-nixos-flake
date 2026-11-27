# OpenRGB lighting (motherboard over i2c), all modes. Sensor kernel modules: system/boot.nix.
{ pkgs, ... }:
{
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
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
}
