# Intel iGPU: media decode, its Vulkan ICD, and keeping apps off the NVIDIA
# dGPU: meldesktop.igpuEnv (used by modes/saver.nix for the whole session and
# by `run-on-igpu` for one app) and meldesktop.intelIcd (llama-swap's Vulkan device).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.meldesktop) igpuEnv;

  # Keep one app off the dGPU (normal mode; in saver everything already is).
  #   run-on-igpu firefox
  runOnIgpu = pkgs.writeShellScriptBin "run-on-igpu" ''
    #!/bin/bash
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "Usage: run-on-igpu <command> [args...]" >&2
      echo "Launches an app off the NVIDIA dGPU: Vulkan/GL on the Intel iGPU," >&2
      echo "Chromium/Electron in software. The compositor stays on the dGPU." >&2
      exit 1
    fi
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") igpuEnv)}
    exec "$@"
  '';
in
{
  options.meldesktop = {
    intelIcd = lib.mkOption {
      readOnly = true;
      type = lib.types.str;
      # Must be the x86_64 JSON: the i686 one declares library_arch "32" and the
      # 64-bit Vulkan loader silently rejects it, so the iGPU never shows up.
      default = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";
      description = "Vulkan ICD manifest of the Intel iGPU.";
    };
    # Tested 2026-11-26 (eglinfo, nvidia-smi, /proc/<pid>/fd):
    #   * Vulkan apps        -> iGPU via VK_ICD_FILENAMES
    #   * GL/EGL apps        -> iGPU only with BOTH the EGL vendor forced to
    #     (Firefox, Qt)         Mesa AND DRI_PRIME naming the Intel card
    #                           (GALLIUM_DRIVER alone does nothing: NVIDIA's EGL wins)
    #   * Chromium/Electron  -> its GPU process can't init (it insists on the
    #     (VS Code, Discord)    compositor's NVIDIA render node), crash-loops for
    #                           ~1 s, then renders in SOFTWARE. Zero VRAM, as wanted.
    igpuEnv = lib.mkOption {
      readOnly = true;
      type = lib.types.attrsOf lib.types.str;
      default = {
        VK_ICD_FILENAMES = config.meldesktop.intelIcd;
        __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
        __GLX_VENDOR_LIBRARY_NAME = "mesa";
        DRI_PRIME = "pci-0000_00_02_0"; # the Intel iGPU (lspci 00:02.0)
      };
      description = "Environment that keeps an app off the NVIDIA dGPU (saver session, run-on-igpu).";
    };
  };

  config = lib.mkMerge [
    {
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vpl-gpu-rt
        ];
      };
    }
    (lib.mkIf config.meldesktop.desktop {
      environment.systemPackages = [ runOnIgpu ];
    })
  ];
}
