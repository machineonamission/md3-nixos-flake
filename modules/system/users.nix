# User accounts. (openrgb's system user: hardware/openrgb.nix.)
{
  users.users.melody = {
    isNormalUser = true;
    description = "Melody";
    extraGroups = [
      "networkmanager"
      "wheel"
      "i2c"
      "input"
    ];
  };
}
