{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Your desktop/lock wallpaper, copied into the store so the pre-login sddm
  # user can read it. The shipped breeze theme points at its own bundled
  # wallpaper, so instead of shipping custom QML we reuse the shipped breeze
  # theme and just write a fresh theme.conf pointing at AURORA.jpg (see
  # ./sddm/aurora-theme.conf).
  auroraTheme = pkgs.runCommand "sddm-aurora-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze $out/share/sddm/themes/aurora
    chmod -R u+w $out/share/sddm/themes/aurora
    sed "s#PLACEHOLDER#${pkgs.kdePackages.plasma-desktop}#" ${./sddm/aurora-theme.conf} > $out/share/sddm/themes/aurora/theme.conf
    cp ${./sddm/AURORA.jpg} $out/share/sddm/themes/aurora/wallpaper.jpg
    chmod a+r $out/share/sddm/themes/aurora/wallpaper.jpg
  '';
in
{
  # ---------------------------------------------------------------------------
  # The desktop stack — SDDM + Plasma 6 + Xorg. Imported ONLY in normal and
  # saver mode (the flake's makeSystem helper decides; see flake.nix). Headless
  # mode never imports this file, so it gets no display manager, no compositor,
  # and no X server — just the raw TTY (see headless.nix).
  #
  # The user / fonts / locale / openrgb / wivrn that used to live here now live
  # in base.nix (shared across all modes).
  # ---------------------------------------------------------------------------

  # Display manager (SDDM, Wayland session)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "aurora";
  };
  services.displayManager.defaultSession = "plasma";

  # Flatpak — desktop app manager (Spotify, etc.). A desktop service, so it is
  # enabled only here (normal / saver mode). In headless mode there is no
  # desktop, so flatpak apps can't run and the service is skipped.
  services.flatpak.enable = true;

  # XDG Desktop Portals — required by Flatpak (asserted by the flatpak module)
  # and used by desktop apps for file choosers, screenshots, screen sharing,
  # etc. The portal backend (xdg-desktop-portal-kde) is provided by Plasma
  # (below); in headless mode neither Flatpak nor Plasma is present.
  xdg.portal.enable = true;

  # Desktop environment (Plasma 6)
  services.desktopManager.plasma6.enable = true;

  # X Server — present only in desktop modes (this file is imported only in
  # normal / saver). The NVIDIA driver renders to the framebuffer that
  # hardware.nvidia.modesetting (in hardware.nix) exposes. In headless mode this
  # whole file is absent, so there is no Xorg and the dGPU's modesetting
  # framebuffer drives the raw TTY instead.
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Put the aurora theme where SDDM looks for it. system.path is a buildEnv over
  # environment.systemPackages (ignoreCollisions = true), so adding the theme
  # there merges its sw/ tree into /run/current-system/sw, where SDDM looks.
  # (environment.etc goes to /etc and is never read by SDDM — that was the
  # reason the first attempt didn't apply.)
  environment.systemPackages = [ auroraTheme ];

  # KDE wallet (per-user credential storage for the Plasma session)
  security.pam.services.melody.kwallet.enable = true;
}
