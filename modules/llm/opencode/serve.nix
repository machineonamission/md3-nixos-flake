# `opencode serve` as a boot-time system service (headless mode only).
# opencode API + web UI, as melody (same config/sessions as interactive use).
# Bound to localhost: anyone who can reach it can run commands as melody, and
# the firewall is off. Reach it through an SSH tunnel:
#   ssh -L 4096:localhost:4096 melody@MelDesktop3   # then open http://localhost:4096
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.meldesktop.mode == "headless") {
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
}
