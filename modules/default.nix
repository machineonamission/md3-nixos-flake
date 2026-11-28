# Every module is imported in every boot mode; mode-specific ones gate
# themselves on config.meldesktop.mode / .desktop / .llm (modes/specialisations.nix).
# "(desktop)" = normal + saver only, "(headless)" = headless only.
{
  imports = [
    # boot modes: normal / saver / headless
    ./modes/specialisations.nix # meldesktop.mode option + the specialisations
    ./modes/mode-command.nix # the `mode` show/switch command
    ./modes/saver.nix # (saver) whole session off the dGPU, KWin exempt
    ./modes/headless.nix # (headless) TTY autologin, NVIDIA for CUDA without Xorg

    # core OS
    ./system/nix.nix # nix daemon, substituters, nixpkgs.config
    ./system/boot.nix # systemd-boot, kernel, sensor modules
    ./system/users.nix
    ./system/locale.nix # timezone, locale
    ./system/fonts.nix
    ./system/networking.nix # hostname, networkmanager, firewall, ssh, warp
    ./system/audio.nix # pipewire

    # hardware + peripherals
    ./hardware/nvidia.nix # dGPU driver, container toolkit
    ./hardware/igpu.nix # Intel iGPU, meldesktop.igpuEnv, run-on-igpu
    ./hardware/firmware.nix # firmware, microcode, fwupd
    ./hardware/storage.nix # ntfs, fuse, partition manager
    ./hardware/disks.nix # smartd, btrfs tools, (later) HDD + scratch mounts
    ./hardware/bluetooth.nix
    ./hardware/printing.nix
    ./hardware/openrgb.nix
    ./hardware/vr.nix # wivrn (Quest 3)
    ./hardware/face-unlock.nix # howdy

    # graphical desktop (desktop)
    ./desktop/plasma.nix # sddm + theme, plasma 6, xorg, kwallet
    ./desktop/flatpak.nix # flatpak + portals
    ./desktop/remote-desktop.nix # xrdp

    # software
    ./programs/cli-tools.nix
    ./programs/git.nix # system git identity
    ./programs/apps.nix # firefox, steam, kdeconnect, onedrive
    ./programs/claude-desktop # (desktop) official Claude Desktop .deb, repackaged

    # running non-Nix software
    ./compat/portable.nix # nix-ld library set + run-portable wrapper
    ./compat/appimage.nix # appimage binfmt, appimage-run, bubblewrap
    ./compat/usr-share-mounts.nix # /usr/share/{fonts,icons,themes} for flatpak

    # local LLMs (models/ is plain data, not a module)
    ./llm/llama-swap # (saver + headless) llama-swap serving llm/models
    ./llm/opencode # opencode packages + generated config; serve.nix (headless)
  ];
}
