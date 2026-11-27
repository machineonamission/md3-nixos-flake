# Filesystems and disks: NTFS (BitLocker HDD), FUSE, KDE Partition Manager.
{
  # Linux 7.1+ NTFS driver (needs linuxPackages_latest, system/boot.nix)
  boot.supportedFilesystems = [ "ntfs" ];

  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };
  programs.partition-manager.enable = true;

  # udisks wants admin auth to mount/unlock internal (non-removable) disks, so
  # Plasma's automount of the second NVMe's NTFS partition and the BitLocker HDD
  # prompted on every login. Let local, active wheel users do it without asking.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.encrypted-unlock-system") &&
          subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
