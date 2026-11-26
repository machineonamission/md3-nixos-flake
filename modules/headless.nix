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
}
