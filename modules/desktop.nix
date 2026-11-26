# Desktop stack (normal + saver modes): SDDM + Plasma 6 + Xorg, flatpak, xrdp,
# and the iGPU-offload helpers.
{ config, lib, pkgs, ... }:
let
  inherit (config.meldesktop) intelIcd mode;
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

  # Render one app on the Intel iGPU. The compositor stays on the dGPU (it
  # drives the displays); the app's frames cross PCIe as dmabufs.
  #   run-on-igpu firefox
  runOnIgpu = pkgs.writeShellScriptBin "run-on-igpu" ''
    #!/bin/bash
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: run-on-igpu <command> [args...]" >&2
      echo "Launches a GUI app with the Intel iGPU forced for rendering." >&2
      echo "The compositor stays on the NVIDIA dGPU; only the app's own" >&2
      echo "rendering is offloaded, freeing dGPU VRAM for llama-swap." >&2
      exit 1
    fi
    export VK_ICD_FILENAMES=${intelIcd}
    export GALLIUM_DRIVER=iris
    exec "$@"
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

  services.flatpak.enable = true;
  xdg.portal.enable = true; # required by flatpak

  security.pam.services.melody.kwallet.enable = true;

  # RDP: a SECOND virtual X11 Plasma session (not a mirror of the monitors).
  # startplasma-x11 sets up the Qt env before ksmserver; dbus-run-session gives
  # it the session bus xrdp-sesman (outside systemd) lacks.
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dbus-run-session startplasma-x11";

  environment.systemPackages = [
    auroraTheme
    runOnIgpu
  ];

  # Saver: every mesa-GL app renders on the iGPU (KWin uses the NVIDIA GL
  # driver, so the displays are unaffected). Vulkan apps already go to the
  # iGPU via VK_ICD_FILENAMES in configuration.nix. Undo per shell with
  # `unset GALLIUM_DRIVER`.
  environment.sessionVariables = lib.mkIf (mode == "saver") { GALLIUM_DRIVER = "iris"; };
}
