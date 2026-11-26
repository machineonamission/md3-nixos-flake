{ ... }:
{
  # ---------------------------------------------------------------------------
  # Extreme GPU VRAM saver — system-wide iGPU rendering. Imported ONLY in saver
  # mode (the flake's makeSystem helper decides — see flake.nix). Normal and
  # headless mode never import this file.
  #
  # GALLIUM_DRIVER=iris routes every mesa-GL app to the Intel iGPU. This is the
  # "extreme GPU VRAM saver" default: every app you launch renders on the iGPU,
  # so the dGPU's VRAM is free for llama-swap. The compositor (KWin) uses the
  # NVIDIA GL driver to drive the displays, so it is NOT affected by this var —
  # your monitors keep working at full resolution/refresh/HDR.
  #
  # Vulkan apps already use the iGPU via the VK_ICD_FILENAMES set in
  # configuration.nix, so this var only adds the mesa-GL (OpenGL) apps on top.
  #
  # This module is a plain attrset with no `config` or `mode` reads, so it cannot
  # cause recursion. It is present or absent purely by virtue of which boot entry
  # you picked.
  #
  # To revert without rebooting (within a saver session): `unset GALLIUM_DRIVER`
  # in your shell, or relaunch the app via a terminal that doesn't have it set.
  # ---------------------------------------------------------------------------
  environment.sessionVariables = {
    GALLIUM_DRIVER = "iris";
  };
}
