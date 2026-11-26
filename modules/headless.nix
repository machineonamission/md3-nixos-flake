{ ... }:
{
  # ---------------------------------------------------------------------------
  # Headless mode — boot to a raw TTY. No display manager, no desktop, no Xorg
  # (those live in desktop.nix, which is NOT imported in headless mode). The
  # dGPU drives this console via its modesetting framebuffer (a few MB of VRAM),
  # and the rest of the card is free for CUDA compute (llama-swap).
  #
  # Autologin as `melody` so the console is immediately usable — no password
  # prompt. This is for local access when you're physically at the machine;
  # remote access is via SSH (see networking.nix). The physical monitors show
  # the TTY; everything else (opencode, llama-swap, nginx) is reached over the
  # network.
  #
  # Imported ONLY in headless mode (the flake's makeSystem helper decides — see
  # flake.nix). In normal / saver mode SDDM owns the console (and masks
  # getty@tty1), so this module is absent. A plain attrset with no `config` or
  # `mode` reads, so it cannot cause recursion.
  # ---------------------------------------------------------------------------

  # Autologin on all virtual consoles.
  services.getty.autologinUser = "melody";

  # ---------------------------------------------------------------------------
  # Make the NVIDIA driver available for CUDA compute.
  #
  # Two things are needed, and neither happens by default in headless mode:
  #
  #   1. The nvidia module must be ENABLED. `hardware.nvidia.enabled` is
  #      read-only and defaults to `nvidiaEnabled || datacenter.enable`, where
  #      `nvidiaEnabled = "nvidia" ∈ services.xserver.videoDrivers`. With no
  #      Xorg that default is false, so the whole module is skipped (lib.mkIf
  #      cfg.enabled) — no .ko files installed, no nvidia_uvm. We set
  #      videoDrivers to ["nvidia"] to flip nvidiaEnabled on. This does NOT
  #      start Xorg (that's services.xserver.enable, still false here) — it
  #      only feeds the nvidia module's enable check.
  #
  #   2. The driver modules must be in the BOOT LOAD LIST. The nvidia module
  #      only adds nvidia/nvidia_modeset/nvidia_drm when
  #      `services.xserver.enable` is true (nixos/modules/hardware/video/
  #      nvidia.nix: `kernelModules = lib.optionals config.services.xserver.enable
  #      [...]`). Xorg is still off, so that list is empty and even an enabled
  #      module loads nothing. We add the module names ourselves.
  #
  # We load the compute stack — `nvidia` (main driver), `nvidia_modeset`
  # (modeset support), `nvidia_uvm` (unified virtual memory, what CUDA uses) —
  # but deliberately NOT `nvidia_drm`: that one registers as a DRM/KMS display
  # driver and would steal the console from the generic `modesetting` driver
  # that drives this TTY, blanking the physical monitors. CUDA does not need
  # nvidia_drm. (nvidia_uvm is also loaded eagerly by the nvidia module for
  # open-module drivers; listing it here makes the requirement explicit and
  # independent of that path.)
  # ---------------------------------------------------------------------------
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
  ];
}
