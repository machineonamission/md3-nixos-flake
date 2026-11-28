# go-hass-agent (nixpkgs, MIT): the Home Assistant "companion app" for this
# machine. Publishes to HA via the mobile_app integration — zero HA-side config:
#   - every /sys/class/hwmon sensor: CPU temps (x86_pkg_temp via coretemp,
#     acpitz), fan RPM, + alarm sensors
#   - Nvidia GPU: temperature, board power (W), utilization, VRAM, fan, clocks
#     (shells out to nvidia-smi; auto-off if absent)
#   - CPU power (W) per RAPL domain — needs root-only /sys/class/powercap
#     energy_uj reads, so OFF for an unprivileged user; see the note below
#   - memory/disk/net/load/frequency/uptime, login + OOM events
#
# One-time registration (writes ~/.config/go-hass-agent/preferences.toml, 600):
#   sudo -u melody env HOME=/home/melody \
#     $(nix build --no-link --print-out-paths nixpkgs#go-hass-agent)/bin/go-hass-agent \
#     register --server https://ha.melhome.me \
#     --token "$(cat ~/.config/opencode/secrets/home-assistant-token)"
# (token renewal: same command with a fresh long-lived token, then restart service)
#
# A SYSTEM service running as melody — not a home-manager user service — because
# HM user services need loginctl linger (HM does not enable it) and would not run
# in saver/headless boot modes, which is exactly when llama-swap heats the CPU.
# Web UI (prefs) stays on localhost:8223.
#
# Optional CPU-power sensors (W): the kernel gates RAPL energy counters to root
# (PLATYPUS CVE-2020-8694 mitigation). To expose them to melody only, uncomment:
#   users.users.melody.extraGroups = [ "rapl-read" ];
#   systemd.tmpfiles.rules = [
#     "z /sys/class/powercap/intel-rapl:*/energy_uj 0440 root rapl-read - -"
#     "z /sys/class/powercap/intel-rapl:*:*/energy_uj 0440 root rapl-read - -"
#   ];
# (group is created implicitly by tmpfiles' group field; check with
#  `sudo -u melody head -c1 /sys/class/powercap/intel-rapl:0/energy_uj`)
{ config, pkgs, ... }:
{
  systemd.services.go-hass-agent = {
    description = "Home Assistant agent (hardware temperature/power sensors -> HA)";
    documentation = [ "https://github.com/joshuar/go-hass-agent" ];
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "systemd-user-sessions.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "melody";
      Group = "melody";
      Environment = [
        "HOME=/home/melody"
        # nvidia-smi normally isn't on a service PATH; the driver package carries
        # it (modules/hardware/nvidia.nix installs it into the package bin/).
        "PATH=${pkgs.go-hass-agent}/bin:${config.hardware.nvidia.package}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
      ExecStart = "${pkgs.go-hass-agent}/bin/go-hass-agent run";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
