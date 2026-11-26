# Boot modes + shared values.
#
# ONE system, three systemd-boot entries (NixOS specialisations):
#   normal   (default entry) — full desktop; dGPU drives the displays
#   saver    "NixOS (saver)" — same desktop, but GUI apps render on the iGPU
#            by default so the dGPU's VRAM stays free for llama-swap
#   headless "NixOS (headless)" — no display manager / desktop / Xorg, raw TTY
#            with autologin; the dGPU is free for CUDA
#
# Each specialisation re-evaluates the whole config with `meldesktop.mode`
# changed, and modules switch on it with `lib.mkIf` (desktop.nix,
# headless.nix). Reading `config` inside mkIf is fine; it's only `imports` that
# can't depend on config.
#
#   sudo nixos-rebuild switch --flake .                           # all 3 entries, activates normal
#   sudo nixos-rebuild test --flake . --specialisation saver      # live-switch, no reboot
#   sudo bootctl set-oneshot nixos-generation-<N>-specialisation-headless.conf   # next boot only
{
  config,
  lib,
  pkgs,
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
    intelIcd = lib.mkOption {
      readOnly = true;
      type = lib.types.str;
      # Must be the x86_64 JSON: the i686 one declares library_arch "32" and the
      # 64-bit Vulkan loader silently rejects it, so the iGPU never shows up.
      default = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";
      description = "Vulkan ICD manifest of the Intel iGPU.";
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
