# Headless mode: monitors show a raw TTY (no desktop.nix stack), and every
# service starts at boot without anyone logging in. Workflow:
#   ssh melody@MelDesktop3
#   sudo /run/current-system/specialisation/headless/bin/switch-to-configuration test
#   ssh -L 4096:localhost:4096 melody@MelDesktop3   # then open http://localhost:4096
# llama-swap (modules/llama) and openrgb (base.nix) are system services already.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.meldesktop.mode == "headless") {
  services.getty.autologinUser = "melody";

  # opencode API + web UI, as melody (same config/sessions as interactive use).
  # Bound to localhost: anyone who can reach it can run commands as melody, and
  # the firewall is off. Reach it through the SSH tunnel above.
  systemd.services.opencode = {
    description = "opencode server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "llama-swap.service"
    ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      git
      bash
      coreutils
    ];
    serviceConfig = {
      User = "melody";
      WorkingDirectory = "/home/melody";
      ExecStart = "${lib.getExe pkgs.opencode} serve --hostname 127.0.0.1 --port 4096";
      Restart = "on-failure";
    };
  };

  # Make the NVIDIA driver usable for CUDA without Xorg. Two things don't
  # happen by default without services.xserver.enable:
  #   1. hardware.nvidia.enabled is derived from "nvidia" ∈ xserver.videoDrivers
  #      (this does NOT start Xorg; that's services.xserver.enable).
  #   2. the nvidia module only adds the kernel modules when xserver.enable is
  #      true, so list them ourselves. NOT nvidia_drm: it would take the console
  #      away from the firmware framebuffer and blank the monitors; CUDA doesn't need it.
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
  ];
}
