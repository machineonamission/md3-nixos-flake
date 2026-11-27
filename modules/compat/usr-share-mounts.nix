# Expose the system's fonts / icons / themes at the FHS paths flatpak (and
# other non-Nix apps) look in, via read-only bindfs mounts.
{ lib, pkgs, ... }:
let
  # /usr/share/<name> <- /run/current-system/sw/share/<source>
  mounts = {
    fonts = "X11/fonts"; # populated by fonts.fontDir
    icons = "icons";
    themes = "themes";
  };
in
{
  fonts.fontDir.enable = true;
  system.fsPackages = [ pkgs.bindfs ];

  fileSystems = lib.mapAttrs' (
    name: source:
    lib.nameValuePair "/usr/share/${name}" {
      device = "/run/current-system/sw/share/${source}";
      fsType = "fuse.bindfs";
      # resolve-symlinks: present store symlinks as real files (OnlyOffice needs it)
      options = [
        "ro"
        "x-gvfs-hide"
        "resolve-symlinks"
      ];
    }
  ) mounts;
}
