# The three internal disks: health monitoring + filesystem tools.
#   990 Pro 2TB (nvme0n1)  /, /boot, swap
#   960 EVO 1TB (nvme1n1)  old, pool-survivor, untrusted -> disposable scratch
#   WD Red 8TB  (sda)      data hoard + backup target
# Migration to btrfs in progress: docs/storage-migration.md
{ pkgs, ... }:
{
  # Logs SMART changes to the journal and wall()s on failure. Plasma's own
  # disk-health notifier (plasma-disks, via udisks) covers the desktop popup.
  # Self-tests: short daily 02:00, long on the 1st of the month 03:00 (the
  # long test on the 8TB HDD takes ~13 h; it runs in the background).
  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -o on -S on -n standby,q -s (S/../.././02|L/../01/./03)";
  };

  environment.systemPackages = with pkgs; [
    smartmontools # smartctl
    nvme-cli
    btrfs-progs
    compsize # actual on-disk size of compressed btrfs files
  ];
}
