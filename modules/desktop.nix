# Desktop stack (normal + saver modes): SDDM + Plasma 6 + Xorg, flatpak, xrdp,
# and the iGPU-offload helpers.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.meldesktop) igpuEnv mode;
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

  # Keep one app off the dGPU (normal mode; in saver everything already is).
  # See meldesktop.igpuEnv for what that means per app type.
  #   run-on-igpu firefox
  runOnIgpu = pkgs.writeShellScriptBin "run-on-igpu" ''
    #!/bin/bash
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: run-on-igpu <command> [args...]" >&2
      echo "Launches an app off the NVIDIA dGPU: Vulkan/GL on the Intel iGPU," >&2
      echo "Chromium/Electron in software. The compositor stays on the dGPU." >&2
      exit 1
    fi
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") igpuEnv)}
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

  # Saver: = `run-on-igpu` for the whole session, read at LOGIN (after a live
  # `mode saver`, log out and back in). Undo per shell:
  # `unset VK_ICD_FILENAMES __EGL_VENDOR_LIBRARY_FILENAMES __GLX_VENDOR_LIBRARY_NAME DRI_PRIME`
  environment.sessionVariables = lib.mkIf (mode == "saver") igpuEnv;

  # ...except KWin: it drives the monitors, which hang off the NVIDIA card, so
  # it must keep NVIDIA's EGL. (Xwayland is its child and inherits this.)
  # A raw `units` drop-in, not `systemd.user.services`: that one would also
  # override KWin's PATH with NixOS's minimal service PATH.
  systemd.user.units."plasma-kwin_wayland.service" = lib.mkIf (mode == "saver") {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      UnsetEnvironment=${toString (lib.attrNames igpuEnv)}
    '';
  };
}
