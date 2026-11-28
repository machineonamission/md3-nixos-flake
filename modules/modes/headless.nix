# Headless mode: monitors show a raw TTY (no desktop/ stack), and every
# service starts at boot without anyone logging in. Workflow:
#   ssh melody@MelDesktop3
#   mode headless   (= sudo /run/current-system/specialisation/headless/bin/switch-to-configuration test)
#   ssh -L 4096:localhost:4096 melody@MelDesktop3   # then open http://localhost:4096
# Also starts in this mode: llama-swap (llm/llama-swap), `claude remote-control`
# in ~/Projects (below). `opencode serve` (llm/opencode/serve.nix) and openrgb
# (hardware/openrgb.nix) run in every mode.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.meldesktop.mode == "headless") {
  services.getty.autologinUser = "melody";

  # Starts with the autologin session. ~/Projects must stay trusted in claude (no TTY to ask on).
  home-manager.users.melody.systemd.user.services.claude-remote-control = {
    Unit.Description = "claude remote-control in ~/Projects";
    Service = {
      WorkingDirectory = "%h/Projects";
      ExecStart = "${pkgs.claude-code}/bin/claude remote-control";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
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
