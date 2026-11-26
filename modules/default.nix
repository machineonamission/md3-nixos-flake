{ ... }:
{
  # ---------------------------------------------------------------------------
  # Module index — the SHARED set, imported in EVERY boot mode (normal / saver /
  # headless). These modules are mode-independent: the user, hardware, networking,
  # services, packages, and llama-swap all exist in all three modes.
  #
  # The MODE-SPECIFIC modules (desktop.nix, gpu-offload.nix, saver.nix,
  # headless.nix) are NOT imported here. They are imported conditionally by the
  # flake's makeSystem helper (see flake.nix), which branches on the `mode`
  # variable — a plain Nix value, not `config`. Branching on `config` would cause
  # infinite recursion; branching on a plain variable is safe.
  # ---------------------------------------------------------------------------
  imports = [
    ./meldesktop.nix # shared values (intelIcd, mode)
    ./boot.nix # systemd-boot, kernel, kernel modules (all modes)
    ./base.nix # user, fonts, locale, openrgb, wivrn (all modes)
    ./hardware.nix # GPU drivers, bluetooth, NTFS, nix-ld, appimage
    ./networking.nix # hostname, networkmanager, ssh, xrdp, warp
    ./services.nix # onedrive, printing, flatpak, pipewire, howdy
    ./packages.nix # system tools, git, firefox, steam, kdeconnect
    ./portable.nix # nix-ld library set + run-portable wrapper
    ./icon-fix.nix # bind mounts for fonts/icons/themes
    ./opencode.nix # opencode (the agent CLI)
    ./llama # llama-swap (local LLM serving — the whole point)
  ];
}
