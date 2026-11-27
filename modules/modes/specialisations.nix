# Boot modes: the meldesktop.mode option and the specialisations that set it.
#
# ONE system, three systemd-boot entries (NixOS specialisations):
#   normal   (default entry) — full desktop, everything on the dGPU, no local LLM
#   saver    "NixOS (saver)" — same desktop, but userspace renders on the iGPU
#            (Vulkan + GL) so the dGPU's VRAM stays free for llama-swap
#   headless "NixOS (headless)" — raw TTY only; llama-swap, opencode serve,
#            openrgb etc. start at boot. Meant for: ssh in, switch, use remotely
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
    llm = lib.mkOption {
      readOnly = true;
      type = lib.types.bool;
      default = mode != "normal";
      description = "Whether local LLM serving (llama-swap) runs in this mode.";
    };
  };

  config = {
    specialisation = lib.genAttrs [ "saver" "headless" ] (m: {
      configuration.meldesktop.mode = m;
    });

    # Store path / `readlink /run/current-system` says which mode is running.
    system.name = "MelDesktop3" + lib.optionalString (mode != "normal") "-${mode}";
  };
}
