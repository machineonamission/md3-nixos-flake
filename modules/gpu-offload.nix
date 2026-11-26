{ pkgs, ... }:
let
  # The Intel iGPU's Vulkan ICD. Must be the x86_64 JSON — the i686 one declares
  # library_arch "32" and the 64-bit loader silently rejects it, so the iGPU
  # never shows up as a Vulkan device.
  intelIcd = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";

  # The run-on-igpu wrapper: launch a command with the Intel iGPU forced for
  # rendering. The compositor stays on the dGPU (it must — it drives the
  # displays); only the wrapped app renders on the iGPU. The app's frames are
  # shuttled over PCIe (dmabuf) to the compositor, which composites them onto
  # the dGPU's framebuffer. The app's rendering never touches dGPU VRAM.
  #
  #   VK_ICD_FILENAMES  -> Vulkan apps use the Intel iGPU (not the NVIDIA ICD).
  #   GALLIUM_DRIVER    -> mesa-GL apps use the Intel iris driver (not the
  #                        NVIDIA GL driver).
  #
  # Usage:
  #   run-on-igpu code
  #   run-on-igpu firefox
  #   run-on-igpu discord --some-flag
  runOnIgpu = pkgs.writeShellScriptBin "run-on-igpu" ''
    #!/bin/bash
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: run-on-igpu <command> [args...]" >&2
      echo "Launches a GUI app with the Intel iGPU forced for rendering." >&2
      echo "The compositor stays on the NVIDIA dGPU; only the app's own" >&2
      echo "rendering is offloaded, freeing dGPU VRAM for llama-swap." >&2
      exit 1
    fi
    export VK_ICD_FILENAMES=${intelIcd}
    export GALLIUM_DRIVER=iris
    exec "$@"
  '';
in
{
  # ---------------------------------------------------------------------------
  # GPU offload — the per-app `run-on-igpu` wrapper. Imported in normal AND
  # saver mode (both have a desktop; the flake's makeSystem helper decides — see
  # flake.nix). Headless mode never imports this file (no GUI apps to offload).
  #
  # This module is mode-agnostic: it just installs the wrapper. The wrapper is
  # useful in both normal mode (per-app offload on demand) and saver mode (where
  # it's redundant with the system-wide env vars but still available). It reads
  # no `config` and no `mode`, so it cannot cause recursion.
  #
  # The system-wide saver env vars (GALLIUM_DRIVER=iris for the whole session)
  # live in saver.nix, which is imported ONLY in saver mode.
  # ---------------------------------------------------------------------------
  environment.systemPackages = [ runOnIgpu ];
}
