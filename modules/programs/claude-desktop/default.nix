# Claude Desktop (desktop modes only). package.nix repackages the official .deb.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.meldesktop.desktop {
  environment.systemPackages = [ (pkgs.callPackage ./package.nix { }) ];
}
