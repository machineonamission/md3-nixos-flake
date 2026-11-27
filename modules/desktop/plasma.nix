# Desktop session (normal + saver modes): SDDM (aurora theme) + Plasma 6 +
# Xorg, KWallet. Saver mode's iGPU session env: modes/saver.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  plasma = pkgs.kdePackages.plasma-desktop;

  # Stock breeze SDDM theme with our wallpaper. SDDM reads themes from
  # /run/current-system/sw/share/sddm/themes, hence systemPackages below.
  auroraTheme = pkgs.runCommand "sddm-aurora-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${plasma}/share/sddm/themes/breeze $out/share/sddm/themes/aurora
    chmod -R u+w $out/share/sddm/themes/aurora
    sed "s#PLACEHOLDER#${plasma}#" ${./sddm/aurora-theme.conf} > $out/share/sddm/themes/aurora/theme.conf
    cp ${./sddm/AURORA.jpg} $out/share/sddm/themes/aurora/wallpaper.jpg
    chmod a+r $out/share/sddm/themes/aurora/wallpaper.jpg
  '';
in
lib.mkIf config.meldesktop.desktop {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "aurora";
  };
  services.displayManager.defaultSession = "plasma";
  services.desktopManager.plasma6.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb.layout = "us";
    xkb.variant = "";
  };

  security.pam.services.melody.kwallet.enable = true;

  environment.systemPackages = [ auroraTheme ];
}
