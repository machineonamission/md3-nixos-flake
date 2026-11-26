# MelDesktop3 host entry point. Everything else lives in ./modules.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules
  ];

  environment.variables.MEMINI_HOME = "personal/melody";

  # nix-ld with a big library set + the `run-portable` wrapper (modules/portable.nix).
  programs.portableApps.enable = true;

  # Do NOT bump this on upgrades; it pins stateful defaults to the install release.
  system.stateVersion = "26.11";
}
