{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest kernel: needed for the Linux 7.1+ NTFS driver (BitLocker HDD).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Extra hardware sensors (temps) for OpenRGB / system monitor.
  boot.kernelModules = [ "coretemp" "nct6683" ];
}
