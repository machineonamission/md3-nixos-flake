# Filesystems and disks: NTFS (BitLocker HDD), FUSE, KDE Partition Manager.
{
  # Linux 7.1+ NTFS driver (needs linuxPackages_latest, system/boot.nix)
  boot.supportedFilesystems = [ "ntfs" ];

  programs.fuse = {
    enable = true;
    userAllowOther = true;
  };
  programs.partition-manager.enable = true;
}
