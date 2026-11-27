# Saver mode: the whole desktop session renders off the NVIDIA dGPU (so its
# VRAM stays free for llama-swap), except KWin. llama-swap itself is gated on
# meldesktop.llm in llm/llama-swap. What "off the dGPU" means per app type:
# meldesktop.igpuEnv in hardware/igpu.nix.
{ config, lib, ... }:
let
  inherit (config.meldesktop) igpuEnv;
in
lib.mkIf (config.meldesktop.mode == "saver") {
  # = `run-on-igpu` for the whole session, read at LOGIN (after a live
  # `mode saver`, log out and back in). Undo per shell:
  # `unset VK_ICD_FILENAMES __EGL_VENDOR_LIBRARY_FILENAMES __GLX_VENDOR_LIBRARY_NAME DRI_PRIME`
  environment.sessionVariables = igpuEnv;

  # ...except KWin: it drives the monitors, which hang off the NVIDIA card, so
  # it must keep NVIDIA's EGL. (Xwayland is its child and inherits this.)
  # A raw `units` drop-in, not `systemd.user.services`: that one would also
  # override KWin's PATH with NixOS's minimal service PATH.
  systemd.user.units."plasma-kwin_wayland.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      UnsetEnvironment=${toString (lib.attrNames igpuEnv)}
    '';
  };
}
