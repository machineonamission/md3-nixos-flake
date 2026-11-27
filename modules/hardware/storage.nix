# Filesystems and disks: NTFS (BitLocker HDD), FUSE, KDE Partition Manager.
{
  # Linux 7.1+ NTFS driver (needs linuxPackages_latest, system/boot.nix)
  boot.supportedFilesystems = [ "ntfs" ];

  # udisks (Plasma/Dolphin automount) has a built-in driver order of
  # `ntfs_drivers=ntfs3,ntfs`, so it picked the old Paragon ntfs3 driver even
  # though the kernel has the new `ntfs` one. Prefer `ntfs`, keep ntfs3 as the
  # fallback. The built-in ntfs:ntfs defaults carry ntfs-3g-only options
  # (windows_names), so keep them to plain uid/gid. Check with
  # `findmnt -no FSTYPE <mountpoint>` -> should say `ntfs`.
  services.udisks2.settings."mount_options.conf".defaults = {
    ntfs_drivers = "ntfs,ntfs3";
    "ntfs:ntfs_defaults" = "uid=$UID,gid=$GID";
    "ntfs:ntfs_allow" = "uid=$UID,gid=$GID,umask,dmask,fmask";
  };

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
