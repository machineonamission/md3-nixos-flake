# Flatpak + XDG portals (normal + saver). /usr/share/{fonts,icons,themes} for
# flatpak apps: compat/usr-share-mounts.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkMerge [
  # Installed in EVERY mode (headless too, where it's dead weight: it pulls in
  # ~200 MiB of Plasma libs). Kept ungated only because it always was.
  { environment.systemPackages = [ pkgs.kdePackages.xdg-desktop-portal-kde ]; }

  (lib.mkIf config.meldesktop.desktop {
    services.flatpak.enable = true;
    xdg.portal.enable = true; # required by flatpak
  })
]
