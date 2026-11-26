# MelDesktop3 host entry point. Everything else lives in ./modules.
{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules
  ];

  environment.variables.MEMINI_HOME = "personal/melody";

  # GUI session env. SubControl bundles its own libvulkan loader but no ICD, so
  # wgpu can't create a surface without this. NOTE: it also forces every other
  # Vulkan app onto the iGPU, in every mode.
  environment.sessionVariables.VK_ICD_FILENAMES = config.meldesktop.intelIcd;

  # nix-ld with a big library set + the `run-portable` wrapper (modules/portable.nix).
  programs.portableApps.enable = true;

  # Do NOT bump this on upgrades; it pins stateful defaults to the install release.
  system.stateVersion = "26.11";
}
