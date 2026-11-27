# Filesystems and disks: NTFS (BitLocker HDD), FUSE, KDE Partition Manager.
{
  # Linux 7.1+ NTFS driver (needs linuxPackages_latest, system/boot.nix)
  boot.supportedFilesystems = [ "ntfs" ];

  # NTFS driver choice: udisks (Plasma/Dolphin automount) uses its built-in
  # order `ntfs_drivers=ntfs3,ntfs`, i.e. the Paragon ntfs3 driver first.
  # Tried preferring the new 7.1+ `ntfs` driver (2026-11): on the HDD it
  # rejected the $INDEX_ALLOCATION of 4 huge directories written by ntfs3
  # ("Corrupt 0xa0 attribute ... run chkdsk", EIO on every file inside),
  # which ntfs3, sleuthkit and a raw MFT parse all read fine. Back on ntfs3.
  # To retry later: services.udisks2.settings."mount_options.conf".defaults
  #   = { ntfs_drivers = "ntfs,ntfs3"; "ntfs:ntfs_defaults" = "uid=$UID,gid=$GID"; };

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
