# Every module is imported in every boot mode; mode-specific ones gate
# themselves on config.meldesktop.mode (see meldesktop.nix).
{
  imports = [
    ./meldesktop.nix # boot modes (specialisations) + shared values
    ./nix.nix # nix daemon + nixpkgs config
    ./boot.nix # bootloader, kernel
    ./base.nix # users, fonts, locale, openrgb, wivrn
    ./hardware.nix # GPU drivers, bluetooth, filesystems
    ./networking.nix # hostname, networkmanager, ssh, warp
    ./services.nix # onedrive, printing, pipewire, howdy
    ./packages.nix # system-wide tools and programs
    ./portable.nix # nix-ld library set + run-portable wrapper
    ./icon-fix.nix # /usr/share/{fonts,icons,themes} bind mounts
    ./opencode.nix
    ./llama # llama-swap
    ./desktop.nix # normal + saver only
    ./headless.nix # headless only
  ];
}
