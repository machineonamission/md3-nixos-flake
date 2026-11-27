# Installed fonts + rendering. (/usr/share/fonts for flatpak: compat/usr-share-mounts.nix.)
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    atkinson-hyperlegible-next
    atkinson-hyperlegible-mono
    noto-fonts
  ];

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
}
