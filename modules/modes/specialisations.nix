# Boot modes: the meldesktop.mode option and the specialisations that set it.
#
# ONE system, three systemd-boot entries (NixOS specialisations):
#   normal   (default entry) — full desktop, everything on the dGPU. llama-swap
#            runs here too now, but as a ghost: very wide --fit margins + short
#            TTL so it never crowds the desktop or any other process.
#   saver    "NixOS (saver)" — same desktop, but userspace renders on the iGPU
#            (Vulkan + GL) so the dGPU's VRAM stays free for llama-swap. The
#            dGPU still idles (~750 MiB) and spikes, so a moderate fit target.
#   headless "NixOS (headless)" — raw TTY only; llama-swap, opencode serve,
#            openrgb etc. start at boot. Meant for: ssh in, switch, use remotely.
#            No desktop competes for VRAM, so the fit target is kept near-zero.
#
# Each specialisation re-evaluates the whole config with `meldesktop.mode`
# changed, and modules switch on it with `lib.mkIf` (desktop/, modes/saver.nix,
# modes/headless.nix, llm/). Reading `config` inside mkIf is fine; it's only
# `imports` that can't depend on config.
#
#   sudo nixos-rebuild switch --flake .   # install: all 3 entries, activates normal
#   mode                                  # which mode am I in?  (mode-command.nix)
#   mode saver | mode headless | mode normal   # live switch
#   mode once headless / mode boot headless    # next boot only / default boot
#
#   The per-mode --fit headroom (MiB) and, for normal mode only, the idle TTL
#   (seconds) are `meldesktop.llm.fitTarget` / `.ttl`. See llm/llama-swap/.
{
  config,
  lib,
  ...
}:
let
  inherit (config.meldesktop) mode;
in
{
  options.meldesktop = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "normal"
        "saver"
        "headless"
      ];
      default = "normal";
      description = "Boot mode. Set per specialisation; never set it by hand.";
    };
    desktop = lib.mkOption {
      readOnly = true;
      type = lib.types.bool;
      default = mode != "headless";
      description = "Whether this mode has a graphical desktop.";
    };
    # Local LLM serving (llama-swap) runs in EVERY mode; what differs is how much
    # room it leaves for everything else. Both values are set per mode below.
    llm = {
      # --fit headroom (MiB) left free on the dGPU after loading a coder. Larger =
      # the coder uses less VRAM, leaving room for the desktop / other processes
      # to grow mid-generation without a CUDA OOM.
      fitTarget = lib.mkOption {
        readOnly = true;
        type = lib.types.ints.unsigned;
        description = "--fit headroom (MiB) for every llama-swap coder in this mode.";
      };
      # Idle-unload TTL (seconds) forced onto EVERY llama-swap model in this mode.
      # null = keep each model's own ttl (saver/headless, where the models are the
      # point); normal mode sets a short one so nothing sits in memory.
      ttl = lib.mkOption {
        readOnly = true;
        type = lib.types.nullOr lib.types.ints.positive;
        description = "Idle-unload TTL (seconds) for all llama-swap models in this mode, or null to keep each model's own.";
      };
    };
  };

  config = {
    specialisation = lib.genAttrs [ "saver" "headless" ] (m: {
      configuration.meldesktop.mode = m;
    });

    # Per-mode --fit headroom and idle TTL.
    #   normal   — a ghost: 1.5 GiB of headroom so it never crowds the desktop,
    #              plus a 60 s TTL so loaded coders unload fast.
    #   saver    — desktop off the dGPU; it still idles ~750 MiB and spikes, so
    #              512 MiB of headroom.
    #   headless — nothing else uses the dGPU, so leave as little headroom as
    #              possible (128 MiB). The monitors' TTY is the firmware
    #              framebuffer (nvidia_drm isn't loaded, see headless.nix), so it
    #              costs the dGPU a few MiB of scanout at most, not a console.
    meldesktop.llm = {
      fitTarget =
        {
          normal = 1536;
          saver = 512;
          headless = 128;
        }
        .${mode};
      ttl = if mode == "normal" then 60 else null;
    };

    # Store path / `readlink /run/current-system` says which mode is running.
    system.name = "MelDesktop3" + lib.optionalString (mode != "normal") "-${mode}";
  };
}
