{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "MelDesktop3";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # Time and locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Services
  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Limit build parallelism to prevent CPU explosion during nixos-rebuild switch
  #  nix.settings.max-jobs = 4;
  #  nix.settings.cores = 0; # use all available cores but respect max-jobs
  #  nix.settings.build-timeout = 3600; # 1 hour per derivation

  # Programs
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # SSH — password auth (boot-accessible)
  services.openssh.enable = true;

  # NTFS filesystem support (Linx 7+ / ntfsprogs-plus, kernel >= 7.1)
  boot.supportedFilesystems = [ "ntfs" ];

  # Filesystem utilities
  programs.partition-manager.enable = true;
  services.cloudflare-warp.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      openssl
      stdenv.cc.cc
      zlib
      libffi
      glibc
    ];
  };
  # Firmware and microcode
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
  hardware.cpu.intel.updateMicrocode = true;

  # Graphics (Intel iGPU for media, NVIDIA for display)
  services.xserver.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  programs.fuse.enable = true;
  programs.fuse.userAllowOther = true;

  system.stateVersion = "26.05";
}
