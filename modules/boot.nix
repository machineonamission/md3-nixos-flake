{ config, pkgs, lib, ... }: {
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Linux 7.1+ "NTFS Resurrection" kernel — required for BitLocker/NTFS HDD access
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Limit build parallelism to prevent CPU explosion during nixos-rebuild switch
  # nix.settings.max-jobs = 4;
  # nix.settings.cores = 0;   # use all available cores but respect max-jobs
  # nix.settings.build-timeout = 3600;  # 1 hour per derivation
}
